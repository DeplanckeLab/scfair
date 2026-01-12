# frozen_string_literal: true

module Search
  class DatasetDocumentBuilder
    def initialize(dataset, ancestor_cache: nil)
      @dataset = dataset
      @ancestor_cache = ancestor_cache || {}
    end

    def as_json
      {
        id: @dataset.id.to_s,
        collection_id: @dataset.collection_id,
        source_reference_id: @dataset.source_reference_id,
        source_url: @dataset.source_url,
        explorer_url: @dataset.explorer_url,
        cell_count: @dataset.cell_count,
        status: @dataset.status,
        source_name: @dataset.source&.name,
        authors: Array(@dataset.study&.authors),
        text_search: build_text_search,
        created_at: @dataset.created_at&.iso8601,
        updated_at: @dataset.updated_at&.iso8601
      }.merge(tree_category_fields)
        .merge(flat_category_fields)
        .merge(name_fields)
    end

    private

    def build_text_search
      parts = [@dataset.source&.name]
      parts.concat Array(@dataset.study&.authors)

      Facet.all.each do |facet|
        association_result = @dataset.send(facet.association_name)

        items = Array(association_result).compact
        parts.concat(items.map(&:name))

        items.each do |item|
          if item.respond_to?(:ontology_term) && item.ontology_term&.synonyms.present?
            parts.concat(item.ontology_term.synonyms)
          end
        end
      end

      parts.compact.join(" ")
    end

    def tree_category_fields
      fields = {}

      Facet.tree_categories.each do |category|
        facet = Facet.find(category)
        items = @dataset.send(facet.association_name)

        # Filter items to only include those with valid ontology prefixes
        valid_items = filter_by_valid_ontology(items, category)

        term_ids = valid_items.map(&:ontology_term_id).compact.uniq

        hierarchy_data = build_hierarchy_data(term_ids, category)

        fields["#{category}_ids"] = term_ids.map(&:to_s)
        fields["#{category}_ancestor_ids"] = hierarchy_data[:ancestor_ids]

        fields["#{category}_hierarchy"] = hierarchy_data[:hierarchy]

        fields["#{category}_names"] = valid_items.map(&:name)
        fields["#{category}_ancestor_names"] = hierarchy_data[:ancestor_names]

        all_synonyms = []
        valid_items.each do |item|
          if item.respond_to?(:ontology_term) && item.ontology_term&.synonyms.present?
            all_synonyms.concat(item.ontology_term.synonyms)
          end
        end
        fields["#{category}_synonyms"] = all_synonyms.uniq
      end

      fields
    end

    def flat_category_fields
      Facet.flat_categories.each_with_object({}) do |category, hash|
        facet = Facet.find(category)
        association_result = @dataset.send(facet.association_name)

        items = Array(association_result).compact

        # Filter items to only include those with valid ontology prefixes
        valid_items = filter_by_valid_ontology(items, category)

        hash["#{category}_ids"] = valid_items.map { |item| item.id.to_s }

        hash["#{category}_names"] = valid_items.map(&:name)
      end
    end

    def name_fields
      fields = {}

      Facet.tree_categories.each do |category|
        facet = Facet.find(category)
        items = @dataset.send(facet.association_name)

        fields["#{category}_names"] = items.map(&:name).uniq
      end

      fields
    end

    def build_hierarchy_data(term_ids, category)
      hierarchy = []
      all_ancestor_ids = Set.new
      all_ancestor_names = Set.new
      model_class = OntologyTerm.model_for_category(category)

      term_ids.each do |term_id|
        term = OntologyTerm.find_by(id: term_id)
        next unless term

        hierarchy << {
          id: term.id.to_s,
          name: term.name,
          synonyms: term.synonyms || [],
          depth: 0,
          is_direct: true
        }

        ancestors_with_depth = get_ancestors_with_depth(term)

        ancestors_with_depth.each do |ancestor, depth|
          next unless valid_ancestor_for_category?(ancestor, model_class)

          all_ancestor_ids << ancestor.id.to_s
          all_ancestor_names << ancestor.name

          hierarchy << {
            id: ancestor.id.to_s,
            name: ancestor.name,
            synonyms: ancestor.synonyms || [],
            depth: depth,
            is_direct: false
          }
        end
      end

      {
        hierarchy: hierarchy.uniq { |h| h[:id] },
        ancestor_ids: (term_ids.map(&:to_s) + all_ancestor_ids.to_a).uniq,
        ancestor_names: all_ancestor_names.to_a
      }
    end

    def valid_ancestor_for_category?(ancestor, model_class)
      return true unless model_class&.respond_to?(:valid_ontology?)
      return false unless ancestor.identifier.present?

      model_class.valid_ontology?(ancestor.identifier)
    end

    def get_ancestors_with_depth(term)
      ancestors_with_depth = []
      visited = Set.new

      if @ancestor_cache&.key?(term.id)
        ancestor_ids = @ancestor_cache[term.id]
        ancestor_ids.each do |ancestor_id|
          next if visited.include?(ancestor_id)
          visited.add(ancestor_id)

          ancestor = OntologyTerm.find_by(id: ancestor_id)
          next unless ancestor

          ancestors_with_depth << [ancestor, 1]
        end

        return ancestors_with_depth
      end

      queue = [[term, 0]]

      while queue.any?
        current_term, depth = queue.shift

        parent_ids = current_term.parent_relationships.pluck(:parent_id)

        parent_ids.each do |parent_id|
          next if visited.include?(parent_id)
          visited.add(parent_id)

          parent = OntologyTerm.find_by(id: parent_id)
          next unless parent

          ancestors_with_depth << [parent, depth + 1]
          queue << [parent, depth + 1]
        end
      end

      ancestors_with_depth
    end

    # Filter items to only include those with valid ontology prefixes for the category
    def filter_by_valid_ontology(items, category)
      model_class = OntologyTerm.model_for_category(category)
      return items unless model_class&.respond_to?(:valid_ontology?)

      items.select do |item|
        next false unless item.ontology_term&.identifier.present?
        model_class.valid_ontology?(item.ontology_term.identifier)
      end
    end
  end
end