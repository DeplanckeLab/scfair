# frozen_string_literal: true

class Facet::Tree::DisplayFilter
  AGGREGATE_RATIO_THRESHOLD = 10
  SIGNIFICANT_DIRECT_THRESHOLD = 50
  SIGNIFICANT_RATIO_THRESHOLD = 15
  MAX_CHILDREN_FOR_GROUPING = 8

  class << self
    # Computes which terms should be displayed at root level using three-step filtering:
    # 1. Filter out ontology roots (terms with no parents like "Disease")
    # 2. Filter out umbrella terms (high ratio AND many children = too generic)
    # 3. Keep only terms with no ancestor in the filtered set
    def compute_display_ids(term_ids, counts, metadata, options = {})
      return [] if term_ids.empty?

      has_search_query = options[:has_search_query] || false

      # Step 1: Filter out ontology roots (terms with no parents)
      has_parents = term_ids.select do |id|
        parent_ids = metadata.dig(id, :parent_ids) || []
        parent_ids.any?
      end
      return [] if has_parents.empty?

      ancestor_ids_set = counts[:ancestor].keys.to_set

      max_ancestor_count = counts[:ancestor].values.max || 0

      # Step 2: Filter out umbrella terms (effective roots)
      not_umbrella = has_parents.select do |id|
        direct_count = counts[:direct][id] || 0
        ancestor_count = counts[:ancestor][id] || 0

        is_leaf_term = direct_count > 0 && direct_count == ancestor_count

        unless has_search_query || is_leaf_term
          if max_ancestor_count > 500 && ancestor_count > max_ancestor_count * 0.8
            next false
          end
        end

        if direct_count > 0
          ratio = ancestor_count.to_f / direct_count
          threshold = direct_count >= SIGNIFICANT_DIRECT_THRESHOLD ? SIGNIFICANT_RATIO_THRESHOLD : AGGREGATE_RATIO_THRESHOLD
          next ratio <= threshold
        end

        child_ids = metadata.dig(id, :child_ids) || []
        dominated_by_child = child_ids.any? do |cid|
          child_ancestor = counts[:ancestor][cid] || 0
          ancestor_count > 0 && child_ancestor >= ancestor_count * 0.9
        end
        next false if dominated_by_child

        parent_ids = metadata.dig(id, :parent_ids) || []

        specific_parents_in_ancestors = parent_ids.select do |pid|
          next false unless ancestor_ids_set.include?(pid)

          parent_direct = counts[:direct][pid] || 0
          parent_ancestor = counts[:ancestor][pid] || 0

          if parent_direct == 0
            term_dominates_parent = parent_ancestor > 500 && ancestor_count > parent_ancestor * 0.85

            next false if term_dominates_parent
            next true
          end

          parent_ratio = parent_ancestor.to_f / parent_direct
          parent_ratio <= AGGREGATE_RATIO_THRESHOLD * 2
        end

        specific_parents_in_ancestors.any?
      end
      return [] if not_umbrella.empty?

      # Step 3: Keep only terms with no ancestor in the filtered set
      not_umbrella_set = not_umbrella.to_set
      not_umbrella.select do |id|
        !has_ancestor_in_set?(id, not_umbrella_set, metadata)
      end
    end

    private

    def count_children_in_results(term_id, term_ids_set, metadata)
      term_ids_set.count do |tid|
        parent_ids = metadata.dig(tid, :parent_ids) || []
        parent_ids.include?(term_id)
      end
    end

    def has_ancestor_in_set?(term_id, target_set, metadata, visited = Set.new)
      return false if visited.include?(term_id)
      visited.add(term_id)

      parent_ids = metadata.dig(term_id, :parent_ids) || []
      parent_ids.each do |pid|
        return true if target_set.include?(pid)
        return true if has_ancestor_in_set?(pid, target_set, metadata, visited)
      end
      false
    end
  end
end
