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
        source_name: @dataset.source&.name,
        authors: Array(@dataset.study&.authors),
        text_search: build_text_search
      }.merge(tree_category_fields)
        .merge(flat_category_fields)
        .merge(name_fields)
    end

    private

    def build_text_search
      parts = [@dataset.source&.name]
      parts.concat Array(@dataset.study&.authors)

      Facets::Catalog.all.each do |config|
        association = Facets::Catalog.association_name(config[:key])
        association_result = @dataset.send(association)

        items = Array(association_result).compact
        parts.concat(items.map(&:name))
      end

      parts.compact.join(" ")
    end

    def tree_category_fields
      fields = {}

      Facets::Catalog.tree_categories.each do |category|
        association = Facets::Catalog.association_name(category)
        items = @dataset.send(association)
        term_ids = items.map(&:ontology_term_id).compact.uniq

        hierarchy_data = build_hierarchy_data(term_ids, category)

        fields["#{category}_ids"] = term_ids.map(&:to_s)
        fields["#{category}_ancestor_ids"] = hierarchy_data[:ancestor_ids]

        fields["#{category}_hierarchy"] = hierarchy_data[:hierarchy]

        fields["#{category}_names"] = items.map(&:name)
        fields["#{category}_ancestor_names"] = hierarchy_data[:ancestor_names]
      end

      fields
    end

    def flat_category_fields
      Facets::Catalog.flat_categories.each_with_object({}) do |category, hash|
        association = Facets::Catalog.association_name(category)
        association_result = @dataset.send(association)

        items = Array(association_result).compact

        hash["#{category}_ids"] = items.map { |item| item.id.to_s }

        hash["#{category}_names"] = items.map(&:name)
      end
    end

    def name_fields
      fields = {}

      Facets::Catalog.tree_categories.each do |category|
        association = Facets::Catalog.association_name(category)
        items = @dataset.send(association)

        fields["#{category}_names"] = items.map(&:name).uniq
      end

      fields
    end

    def build_hierarchy_data(term_ids, category)
      hierarchy = []
      all_ancestor_ids = Set.new
      all_ancestor_names = Set.new

      term_ids.each do |term_id|
        term = OntologyTerm.find_by(id: term_id)
        next unless term

        hierarchy << {
          id: term.id.to_s,
          name: term.name,
          depth: 0,
          is_direct: true
        }

        ancestors_with_depth = get_ancestors_with_depth(term)

        ancestors_with_depth.each do |ancestor, depth|
          all_ancestor_ids << ancestor.id.to_s
          all_ancestor_names << ancestor.name

          hierarchy << {
            id: ancestor.id.to_s,
            name: ancestor.name,
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
  end
end