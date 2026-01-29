# frozen_string_literal: true

class Facet::Tree::DisplayFilter
  AGGREGATE_RATIO_THRESHOLD = 10
  MAX_CHILDREN_FOR_GROUPING = 8

  class << self
    # Computes which terms should be displayed at root level using three-step filtering:
    # 1. Filter out ontology roots (terms with no parents like "Disease")
    # 2. Filter out umbrella terms (high ratio AND many children = too generic)
    # 3. Keep only terms with no ancestor in the filtered set
    def compute_display_ids(term_ids, counts, metadata)
      return [] if term_ids.empty?

      term_ids_set = term_ids.to_set

      # Step 1: Filter out ontology roots (terms with no parents)
      has_parents = term_ids.select do |id|
        parent_ids = metadata.dig(id, :parent_ids) || []
        parent_ids.any?
      end
      return [] if has_parents.empty?

      ancestor_ids_set = counts[:ancestor].keys.to_set

      # Step 2: Filter out umbrella terms (effective roots)
      not_umbrella = has_parents.select do |id|
        direct_count = counts[:direct][id] || 0
        ancestor_count = counts[:ancestor][id] || 0

        if direct_count > 0
          ratio = ancestor_count.to_f / direct_count
          next ratio <= AGGREGATE_RATIO_THRESHOLD
        end

        parent_ids = metadata.dig(id, :parent_ids) || []

        specific_parents_in_ancestors = parent_ids.select do |pid|
          next false unless ancestor_ids_set.include?(pid)

          parent_direct = counts[:direct][pid] || 0
          parent_ancestor = counts[:ancestor][pid] || 0

          if parent_direct == 0
            next false if parent_ancestor > 500 && ancestor_count > parent_ancestor * 0.97
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
