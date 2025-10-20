# frozen_string_literal: true

namespace :search do
  desc "Create Elasticsearch datasets index and alias"
  task setup: :environment do
    client = ElasticsearchClient
    index_name = "datasets-v1"
    alias_name = "datasets"

    mapping_path = Rails.root.join("config/elasticsearch/datasets.json")
    body = JSON.parse(File.read(mapping_path))

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

  desc "Bulk reindex completed datasets"
  task reindex: :environment do
    scope = Dataset.completed.includes(
      :study, :source, :cell_types, :suspension_types,
      :organisms, :tissues, :developmental_stages, :diseases, :sexes, :technologies
    )
    puts "Reindexing #{scope.count} datasets..."
    Search::DatasetIndexer.bulk_index(scope)
    puts "Done."
  end

  desc "Create Elasticsearch ontology_terms index"
  task setup_ontology: :environment do
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

  desc "Index ontology terms into ES (includes directly-used terms AND all their ancestors)"
  task index_ontology_terms: :environment do
    STDOUT.sync = true

    client = ElasticsearchClient
    index_alias = "ontology_terms"

    # Collect directly-used term IDs per category (tree categories only)
    used_by_category = Facets::Catalog.models_with_ontology.transform_values do |model|
      model.where.not(ontology_term_id: nil).distinct.pluck(:ontology_term_id)
    end

    puts "Directly-used terms per category:"
    used_by_category.each { |cat, ids| puts "  #{cat}: #{ids.size} terms" }

    direct_ids = used_by_category.values.reduce(Set.new, :|)

    # Build ancestor cache to find all ancestors of directly-used terms
    puts "Building ancestor relationships..."
    parent_pairs = OntologyTermRelationship.pluck(:parent_id, :child_id)
    parents_by_child = Hash.new { |h, k| h[k] = [] }
    parent_pairs.each { |pid, cid| parents_by_child[cid] << pid }

    # Collect all ancestors via BFS traversal
    all_ids = direct_ids.dup
    direct_ids.each do |term_id|
      visited = Set.new
      queue = parents_by_child[term_id].dup

      while (parent_id = queue.shift)
        next if visited.include?(parent_id)
        visited.add(parent_id)
        all_ids.add(parent_id)
        queue.concat(parents_by_child[parent_id])
      end
    end

    puts "Total terms to index (direct + ancestors): #{all_ids.size}"

    # Category assignment: direct terms get their category, ancestors inherit from descendants
    category_for_id = {}
    used_by_category.each do |cat, ids|
      ids.each { |tid| category_for_id[tid] = cat }
    end

    # For ancestor terms, infer category from any direct descendant
    (all_ids - direct_ids).each do |ancestor_id|
      # Find any descendant that has a category
      direct_ids.each do |direct_id|
        next unless category_for_id[direct_id]

        # Check if ancestor_id is in the ancestors of direct_id
        visited = Set.new
        queue = parents_by_child[direct_id].dup

        while (parent_id = queue.shift)
          next if visited.include?(parent_id)
          visited.add(parent_id)

          if parent_id == ancestor_id
            category_for_id[ancestor_id] ||= category_for_id[direct_id]
            break
          end

          queue.concat(parents_by_child[parent_id])
        end

        break if category_for_id[ancestor_id]
      end
    end

    # Load relationships to build parent/child maps for all terms (direct + ancestors)
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

  desc "Reset ontology_terms index (delete old indices and recreate)"
  task reset_ontology: :environment do
    client = ElasticsearchClient
    alias_name = "ontology_terms"

    # Resolve alias to indices
    begin
      aliased = client.indices.get_alias(name: alias_name).keys
    rescue StandardError
      aliased = []
    end

    aliased.each do |idx|
      puts "Deleting index #{idx}"
      client.indices.delete(index: idx) rescue nil
    end

    Rake::Task["search:setup_ontology"].invoke
  end

  desc "Reindex ontology terms (reset + index, with refresh paused)"
  task reindex_ontology: :environment do
    client = ElasticsearchClient
    Rake::Task["search:reset_ontology"].invoke

    # Pause refresh for speed
    client.indices.put_settings(index: "ontology_terms", body: { index: { refresh_interval: -1 } })
    Rake::Task["search:index_ontology_terms"].invoke
    # Restore refresh
    client.indices.put_settings(index: "ontology_terms", body: { index: { refresh_interval: "1s" } })
    client.indices.refresh(index: "ontology_terms")
  end

  desc "Reset datasets index (delete aliased indices and recreate with current mapping)"
  task reset_datasets: :environment do
    client = ElasticsearchClient
    alias_name = "datasets"

    # Delete indices behind alias
    begin
      aliased = client.indices.get_alias(name: alias_name).keys
    rescue StandardError
      aliased = []
    end

    aliased.each do |idx|
      puts "Deleting index #{idx}"
      client.indices.delete(index: idx) rescue nil
    end

    # Create a fresh versioned index using current mapping file
    index_name = "datasets-v1"
    mapping_path = Rails.root.join("config/elasticsearch/datasets.json")
    body = JSON.parse(File.read(mapping_path))
    client.indices.create(index: index_name, body: body)
    client.indices.put_alias(index: index_name, name: alias_name)
    puts "Aliased #{index_name} -> #{alias_name}"
  end

  desc "Reindex datasets into fresh UUID-based mapping (reset + index, with refresh paused)"
  task reindex_datasets: :environment do
    STDOUT.sync = true
    client = ElasticsearchClient
    Rake::Task["search:reset_datasets"].invoke

    # Pause refresh for speed
    client.indices.put_settings(index: "datasets", body: { index: { refresh_interval: -1 } })

    # Pre-build ancestor cache to avoid N+1 queries
    puts "Building ancestor cache..."
    start_cache = Time.now
    
    # Load all ontology term relationships into memory
    parent_pairs = OntologyTermRelationship.pluck(:parent_id, :child_id)
    parents_by_child = Hash.new { |h, k| h[k] = [] }
    parent_pairs.each { |pid, cid| parents_by_child[cid] << pid }
    
    # Compute ancestors for all terms (BFS traversal)
    ancestor_cache = Hash.new { |h, k| h[k] = [] }
    OntologyTerm.find_each do |term|
      visited = Set.new
      queue = parents_by_child[term.id].dup
      ancestors = []
      
      while (parent_id = queue.shift)
        next if visited.include?(parent_id)
        visited.add(parent_id)
        ancestors << parent_id
        queue.concat(parents_by_child[parent_id])
      end
      
      ancestor_cache[term.id] = ancestors
    end
    
    puts "Ancestor cache built in #{(Time.now - start_cache).round(2)}s (#{ancestor_cache.size} terms)"

    # Bulk index all completed datasets
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
      
      # Send bulk request with retry logic
      begin
        ElasticsearchClient.bulk(body: buffer, refresh: false)
        processed += batch.size
        
        # Progress reporting with ETA
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

    # Restore refresh and refresh once
    puts "Finalizing index..."
    client.indices.put_settings(index: "datasets", body: { index: { refresh_interval: "1s" } })
    client.indices.refresh(index: "datasets")
    
    total_time = Time.now - start_time
    puts "✓ Datasets reindexed in #{(total_time / 60).round(1)} minutes (avg: #{(total / total_time).round(1)} docs/s)"
  end
end
