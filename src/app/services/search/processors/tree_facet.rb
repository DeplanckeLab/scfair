module Search
  module Processors
    class TreeFacet
      def initialize(params, category)
        @params = params
        @category = category
        @param_key = Facets::Catalog.param_key(category)
      end

      def process(aggregation)
        return [] unless aggregation

        buckets = extract_buckets(aggregation)
        return [] if buckets[:direct].empty?

        build_tree_nodes(buckets, find_roots: true)
      end

      def process_children(aggregation, parent_id)
        return [] unless aggregation

        buckets = extract_children_buckets(aggregation, parent_id)
        build_tree_nodes(buckets, find_roots: false)
      end

      private

      def append_ontology_code_to_duplicates(nodes, terms_metadata)
        name_groups = nodes.group_by { |node| node.name.to_s.downcase }

        duplicate_names = name_groups.select { |_, group| group.size > 1 }.keys

        return nodes if duplicate_names.empty?

        nodes.map do |node|
          if duplicate_names.include?(node.name.to_s.downcase)
            identifier = terms_metadata.dig(node.id, :identifier)
            ontology_prefix = extract_ontology_prefix(identifier)

            if ontology_prefix
              Facets::TreeNode.new(
                id: node.id,
                name: "#{node.name} (#{ontology_prefix})",
                count: node.count,
                has_children: node.has_children,
                has_selected_children: node.has_selected_children
              )
            else
              node
            end
          else
            node
          end
        end
      end

      def extract_ontology_prefix(identifier)
        return nil unless identifier

        identifier.split(":").first
      end

      def extract_buckets(agg)
        {
          ancestor: agg.dig("ancestor_terms", "buckets") || agg.dig("aggs", "ancestor_terms", "buckets") || [],
          direct: agg.dig("direct_terms", "buckets") || agg.dig("aggs", "direct_terms", "buckets") || []
        }
      end

      def extract_children_buckets(agg, parent_id)
        key = parent_id ? "#{@category}_children" : "#{@category}_roots"
        term_key = parent_id ? "children_terms" : "root_terms"

        {
          ancestor: agg.dig(key, term_key, "buckets") || [],
          direct: agg.dig(key, "direct_terms", "buckets") || []
        }
      end

      def build_tree_nodes(buckets, find_roots: true)
        counts_by_id = buckets[:ancestor].to_h { |b| [b["key"], b["doc_count"]] }
        direct_counts_by_id = buckets[:direct].to_h { |b| [b["key"], b["doc_count"]] }
        ancestor_ids = buckets[:ancestor].map { |b| b["key"] }
        direct_ids = buckets[:direct].map { |b| b["key"] }

        return [] if ancestor_ids.empty?

        selected_ids = Array(@params[@param_key]).map(&:to_s).to_set
        terms_metadata = OntologyTermLookup.fetch_terms((direct_ids + ancestor_ids).uniq)
        hierarchy = Facets::TreeHierarchy.new(terms_metadata)

        display_ids = if find_roots
          return [] if direct_ids.empty?
          hierarchy.identify_roots(direct_ids, counts_by_id, direct_counts_by_id)
        else
          ancestor_ids
        end
        return [] if display_ids.empty?

        has_children_set = hierarchy.nodes_with_children(display_ids, direct_ids)
        nodes_with_selected_children = selected_ids.any? ? OntologyTermLookup.parents_of_set(selected_ids.to_a).to_set : Set.new

        nodes = display_ids.filter_map do |id|
          count = counts_by_id[id]
          next if count.nil? || count.zero?

          Facets::TreeNode.new(
            id: id,
            name: terms_metadata.dig(id, :name) || id,
            count: count,
            has_children: has_children_set.include?(id),
            has_selected_children: nodes_with_selected_children.include?(id)
          )
        end

        nodes = append_ontology_code_to_duplicates(nodes, terms_metadata)

        hierarchy.sort_by_selection(nodes, selected_ids, nodes_with_selected_children).map(&:to_h)
      end
    end
  end
end
