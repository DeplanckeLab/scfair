module Search
  module Processors
    class TreeFacet
      include Search::Concerns::DuplicateLabeler

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

      def process_with_structure(filtered_aggregation, unfiltered_structure)
        return [] unless filtered_aggregation

        buckets = extract_buckets(filtered_aggregation)
        return [] if buckets[:direct].empty?

        filtered_counts_by_id = buckets[:ancestor].to_h { |b| [b["key"], b["doc_count"]] }
        filtered_ancestor_ids = buckets[:ancestor].map { |b| b["key"] }
        filtered_direct_ids = buckets[:direct].map { |b| b["key"] }

        visible_roots = unfiltered_structure[:visible_roots]
        unfiltered_terms_metadata = unfiltered_structure[:terms_metadata]

        filtered_terms_metadata = OntologyTermLookup.fetch_terms(
          (filtered_direct_ids + filtered_ancestor_ids).uniq
        )

        terms_metadata = unfiltered_terms_metadata.merge(filtered_terms_metadata)

        hierarchy = Facets::TreeHierarchy.new(terms_metadata)
        selected_ids = Array(@params[@param_key]).map(&:to_s).to_set

        display_ids = if selected_ids.any?
          selected_with_ancestors = build_ancestor_paths(
            selected_ids.to_a,
            visible_roots,
            filtered_direct_ids,
            terms_metadata
          )

          combined_ids = (visible_roots & filtered_ancestor_ids) | selected_with_ancestors

          selected_terms_with_parents = selected_ids.select do |selected_id|
            parent_ids = terms_metadata.dig(selected_id, :parent_ids) || []
            is_visible_root = visible_roots.include?(selected_id)

            !is_visible_root && (parent_ids & filtered_ancestor_ids).any?
          end

          combined_ids - selected_terms_with_parents.to_a
        else
          visible_roots & filtered_ancestor_ids
        end

        display_ids = display_ids.select { |id| filtered_counts_by_id[id].to_i > 0 }

        return [] if display_ids.empty?

        has_children_set = hierarchy.nodes_with_children(display_ids, filtered_direct_ids)
        nodes_with_selected_children = selected_ids.any? ?
          Search::OntologyTermLookup.parents_of_set(selected_ids.to_a).to_set : Set.new

        nodes = display_ids.filter_map do |id|
          count = filtered_counts_by_id[id]
          next if count.nil? || count.zero?

          name = (terms_metadata.dig(id, :name) || id).to_s.capitalize

          Facets::TreeNode.new(
            id: id,
            name: name,
            count: count,
            has_children: has_children_set.include?(id),
            has_selected_children: nodes_with_selected_children.include?(id)
          )
        end

        nodes = label_duplicates(nodes) { |node| terms_metadata.dig(node.id, :identifier) }
        hierarchy.sort_by_selection(nodes, selected_ids, nodes_with_selected_children).map(&:to_h)
      end

      private

      def build_ancestor_paths(selected_ids, visible_roots, filtered_direct_ids, terms_metadata)
        paths = Set.new

        selected_ids.each do |selected_id|
          next if visible_roots.include?(selected_id)

          parent_ids = terms_metadata.dig(selected_id, :parent_ids) || []
          available_parents = parent_ids & filtered_direct_ids

          if available_parents.any?
            available_parents.each do |parent_id|
              parent_path = trace_to_visible_root(parent_id, visible_roots, filtered_direct_ids, terms_metadata)
              paths.merge(parent_path)
            end
          else
            current_path = trace_to_visible_root(selected_id, visible_roots, filtered_direct_ids, terms_metadata)
            paths.merge(current_path)
          end
        end

        paths.to_a
      end

      def trace_to_visible_root(term_id, visible_roots, filtered_direct_ids, terms_metadata, visited = Set.new)
        return [] if visited.include?(term_id)
        visited.add(term_id)

        return [term_id] if visible_roots.include?(term_id)

        parent_ids = terms_metadata.dig(term_id, :parent_ids) || []

        available_parents = parent_ids & filtered_direct_ids

        return [term_id] if available_parents.empty?

        path = [term_id]
        available_parents.each do |parent_id|
          parent_path = trace_to_visible_root(parent_id, visible_roots, filtered_direct_ids, terms_metadata, visited)
          path.concat(parent_path)
        end

        path.uniq
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
          roots = hierarchy.identify_roots(direct_ids, counts_by_id, direct_counts_by_id)

          selected_in_ancestors = selected_ids.to_a & ancestor_ids
          missing_selected = selected_in_ancestors - roots

          selected_children_with_parents = missing_selected.select do |child_id|
            parent_ids = terms_metadata.dig(child_id, :parent_ids) || []
            parent_ids.any? { |pid| direct_ids.include?(pid) || ancestor_ids.include?(pid) }
          end

          selected_roots = missing_selected - selected_children_with_parents

          (roots + selected_roots).uniq
        else
          ancestor_ids.uniq
        end
        return [] if display_ids.empty?

        has_children_set = hierarchy.nodes_with_children(display_ids, direct_ids)
        nodes_with_selected_children = selected_ids.any? ? OntologyTermLookup.parents_of_set(selected_ids.to_a).to_set : Set.new

        nodes = display_ids.filter_map do |id|
          count = counts_by_id[id]
          next if count.nil? || count.zero?

          name = (terms_metadata.dig(id, :name) || id).to_s.capitalize

          Facets::TreeNode.new(
            id: id,
            name: name,
            count: count,
            has_children: has_children_set.include?(id),
            has_selected_children: nodes_with_selected_children.include?(id)
          )
        end

        nodes = label_duplicates(nodes) { |node| terms_metadata.dig(node.id, :identifier) }

        hierarchy.sort_by_selection(nodes, selected_ids, nodes_with_selected_children).map(&:to_h)
      end
    end
  end
end
