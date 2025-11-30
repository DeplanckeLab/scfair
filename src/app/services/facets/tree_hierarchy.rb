module Facets
  class TreeHierarchy
    def initialize(terms_metadata)
      @terms_metadata = terms_metadata
    end

    def identify_roots(term_ids, counts_by_id = {}, direct_counts_by_id = {})
      max_count = counts_by_id.values.max || 0
      universal_term_threshold = max_count * 0.9 # Terms covering >90% of data are too universal
      generic_parent_threshold = max_count * 0.7 # Parents covering >70% used for hiding logic

      candidate_ids = term_ids.reject do |id|
        term_count = counts_by_id[id] || 0
        term_count > universal_term_threshold
      end

      hidden_by = {}
      candidate_ids.each do |id|
        parent_ids = @terms_metadata.dig(id, :parent_ids) || []
        parents_in_candidates = parent_ids & candidate_ids

        parents_to_hide_under = parents_in_candidates.reject do |parent_id|
          parent_count = counts_by_id[parent_id] || 0
          parent_count > generic_parent_threshold
        end

        hidden_by[id] = parents_to_hide_under if parents_to_hide_under.any?
      end

      visible_ids = candidate_ids.to_set
      changed = true

      while changed
        changed = false
        new_visible_ids = visible_ids.dup

        hidden_by.each do |child_id, parent_ids|
          next unless visible_ids.include?(child_id)

          has_visible_parent = parent_ids.any? { |pid| visible_ids.include?(pid) }

          if has_visible_parent
            new_visible_ids.delete(child_id)
            changed = true
          end
        end

        visible_ids = new_visible_ids
      end

      visible_ids.to_a
    end

    def nodes_with_children(parent_ids, scoped_term_ids)
      parent_ids.select { |pid| has_children_in_scope?(pid, scoped_term_ids) }.to_set
    end

    def sort_by_selection(nodes, selected_ids, nodes_with_selected_children)
      nodes.sort_by do |node|
        is_relevant = selected_ids.include?(node.id.to_s) ||
                     nodes_with_selected_children.include?(node.id)
        [is_relevant ? 0 : 1, node.name.downcase]
      end
    end

    private

    def has_children_in_scope?(parent_id, scoped_term_ids)
      child_ids = @terms_metadata.dig(parent_id, :child_ids) || []
      (child_ids & scoped_term_ids).any?
    end
  end
end
