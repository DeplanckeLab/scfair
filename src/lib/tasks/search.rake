# frozen_string_literal: true

namespace :search do
  desc "Create Elasticsearch datasets index and alias"
  task setup_datasets: :environment do
    client = ElasticsearchClient
    index_name = "datasets-v1"
    alias_name = "datasets"

    mapping_path = Rails.root.join("config/elasticsearch/datasets.json")
    body = JSON.parse(File.read(mapping_path))

    if client.indices.exists?(index: alias_name) && !client.indices.exists_alias?(name: alias_name)
      puts "Deleting existing '#{alias_name}' index (not an alias)..."
      client.indices.delete(index: alias_name)
    end

    if client.indices.exists?(index: index_name)
      puts "Index #{index_name} already exists"
    else
      client.indices.create(index: index_name, body: body)
      puts "Created index #{index_name}"
    end

    unless client.indices.exists_alias?(name: alias_name)
      client.indices.put_alias(index: index_name, name: alias_name)
      puts "Aliased #{index_name} -> #{alias_name}"
    end
  end

  desc "Index all datasets with optimization (reset + ancestor cache + progress)"
  task index_datasets: :environment do
    STDOUT.sync = true
    client = ElasticsearchClient
    alias_name = "datasets"

    begin
      aliased = client.indices.get_alias(name: alias_name).keys
    rescue StandardError
      aliased = []
    end

    aliased.each do |idx|
      puts "Deleting index #{idx}"
      client.indices.delete(index: idx) rescue nil
    end

    index_name = "datasets-v1"
    mapping_path = Rails.root.join("config/elasticsearch/datasets.json")
    body = JSON.parse(File.read(mapping_path))
    client.indices.create(index: index_name, body: body)
    client.indices.put_alias(index: index_name, name: alias_name)
    puts "Aliased #{index_name} -> #{alias_name}"

    client.indices.put_settings(index: "datasets", body: { index: { refresh_interval: -1 } })

    puts "Building ancestor cache..."
    start_cache = Time.now

    used_term_ids = Set.new
    Facets::Catalog.models_with_ontology.each_value do |model|
      used_term_ids.merge(model.where.not(ontology_term_id: nil).distinct.pluck(:ontology_term_id))
    end
    puts "Found #{used_term_ids.size} unique terms used in datasets"

    parent_pairs = OntologyTermRelationship.pluck(:parent_id, :child_id)
    parents_by_child = Hash.new { |h, k| h[k] = [] }
    parent_pairs.each { |pid, cid| parents_by_child[cid] << pid }

    ancestor_cache = Hash.new { |h, k| h[k] = [] }
    used_term_ids.each do |term_id|
      visited = Set.new
      queue = parents_by_child[term_id].dup
      ancestors = []

      while (parent_id = queue.shift)
        next if visited.include?(parent_id)
        visited.add(parent_id)
        ancestors << parent_id
        queue.concat(parents_by_child[parent_id])
      end

      ancestor_cache[term_id] = ancestors
    end

    puts "Ancestor cache built in #{(Time.now - start_cache).round(2)}s (#{ancestor_cache.size} terms)"

    scope = Dataset.completed.includes(
      :study, :source, :cell_types, :suspension_types,
      :organisms, :tissues, :developmental_stages, :diseases, :sexes, :technologies
    )
    total = scope.count
    puts "Reindexing #{total} datasets..."

    start_time = Time.now
    buffer = []
    processed = 0
    batch_size = 250

    scope.find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |dataset|
        buffer << { index: { _index: "datasets", _id: dataset.id } }
        buffer << Search::DatasetDocumentBuilder.new(dataset, ancestor_cache: ancestor_cache).as_json
      end

      begin
        ElasticsearchClient.bulk(body: buffer, refresh: false)
        processed += batch.size

        elapsed = Time.now - start_time
        rate = processed / elapsed
        remaining = total - processed
        eta_seconds = remaining / rate
        eta_formatted = Time.at(eta_seconds).utc.strftime("%H:%M:%S")

        puts "Indexed #{processed}/#{total} (#{(processed.to_f / total * 100).round(1)}%) | Rate: #{rate.round(1)} docs/s | ETA: #{eta_formatted}"
      rescue StandardError => e
        puts "ERROR in batch starting at #{processed}: #{e.message}"
        puts "Retrying in 2s..."
        sleep 2
        retry
      ensure
        buffer.clear
      end
    end

    puts "Finalizing index..."
    client.indices.put_settings(index: "datasets", body: { index: { refresh_interval: "1s" } })
    client.indices.refresh(index: "datasets")

    total_time = Time.now - start_time
    puts "✓ Datasets reindexed in #{(total_time / 60).round(1)} minutes avg: #{(total / total_time).round(1)} docs/s"
  end

  desc "Create Elasticsearch ontology_terms index"
  task setup_ontology_terms: :environment do
    client = ElasticsearchClient
    index_name = "ontology_terms-v1"
    alias_name = "ontology_terms"

    mapping_path = Rails.root.join("config/elasticsearch/ontology_terms.json")
    body = JSON.parse(File.read(mapping_path))

    unless client.indices.exists?(index: index_name)
      client.indices.create(index: index_name, body: body)
      puts "Created index #{index_name}"
    end

    unless client.indices.exists_alias?(name: alias_name)
      client.indices.put_alias(index: index_name, name: alias_name)
      puts "Aliased #{index_name} -> #{alias_name}"
    end
  end

  desc "Index ontology terms (includes directly-used terms + all ancestors)"
  task index_ontology_terms: :environment do
    STDOUT.sync = true
    client = ElasticsearchClient
    index_alias = "ontology_terms"

    used_by_category = Facets::Catalog.models_with_ontology.transform_values do |model|
      model.where.not(ontology_term_id: nil).distinct.pluck(:ontology_term_id)
    end

    puts "Directly-used terms per category:"
    used_by_category.each { |cat, ids| puts "  #{cat}: #{ids.size} terms" }

    direct_ids = used_by_category.values.reduce(Set.new, :|)

    puts "Building ancestor relationships..."
    parent_pairs = OntologyTermRelationship.pluck(:parent_id, :child_id)
    parents_by_child = Hash.new { |h, k| h[k] = [] }
    parent_pairs.each { |pid, cid| parents_by_child[cid] << pid }

    all_ids = direct_ids.dup
    ancestor_to_category = {}

    direct_ids.each do |term_id|
      category = used_by_category.find { |_cat, ids| ids.include?(term_id) }&.first

      visited = Set.new
      queue = parents_by_child[term_id].dup

      while (parent_id = queue.shift)
        next if visited.include?(parent_id)
        visited.add(parent_id)
        all_ids.add(parent_id)

        ancestor_to_category[parent_id] ||= category if category

        queue.concat(parents_by_child[parent_id])
      end
    end

    puts "Total terms to index (direct + ancestors): #{all_ids.size}"

    category_for_id = {}
    used_by_category.each do |cat, ids|
      ids.each { |tid| category_for_id[tid] = cat }
    end
    category_for_id.merge!(ancestor_to_category)

    term_parent_pairs = OntologyTermRelationship
      .where(child_id: all_ids.to_a)
      .or(OntologyTermRelationship.where(parent_id: all_ids.to_a))
      .pluck(:parent_id, :child_id)

    children_by_parent = Hash.new { |h, k| h[k] = [] }
    parents_by_child_final = Hash.new { |h, k| h[k] = [] }
    term_parent_pairs.each do |pid, cid|
      children_by_parent[pid] << cid if all_ids.include?(pid)
      parents_by_child_final[cid] << pid if all_ids.include?(cid)
    end

    total = all_ids.size
    puts "Indexing #{total} ontology terms..."

    name_by_id = OntologyTerm
      .where(id: all_ids.to_a)
      .pluck(:id, :identifier, :name)
      .to_h { |id, ident, name| [id, { identifier: ident, name: name }] }

    buffer = []
    processed = 0

    OntologyTerm.where(id: all_ids.to_a).find_in_batches(batch_size: 1000) do |terms|
      terms.each do |term|
        parent_ids = parents_by_child_final[term.id].select { |pid| all_ids.include?(pid) }
        child_ids = children_by_parent[term.id].select { |cid| all_ids.include?(cid) }

        doc = {
          id: term.id,
          identifier: name_by_id[term.id][:identifier],
          name: name_by_id[term.id][:name],
          category: category_for_id[term.id],
          parent_ids: parent_ids,
          child_ids: child_ids
        }

        buffer << { index: { _index: index_alias, _id: term.id } }
        buffer << doc
        processed += 1
      end

      client.bulk(body: buffer, refresh: false) if buffer.any?
      buffer.clear
      puts "Indexed #{processed}/#{total}" if (processed % 1000).zero?
    end

    client.indices.refresh(index: index_alias)
    puts "✓ Indexed #{total} ontology terms."
  end
end
