# frozen_string_literal: true

class Facet::Tree::DisplayFilter
  AGGREGATE_RATIO_THRESHOLD = 10

  class << self
    # Computes which terms should be displayed at root level using three-step filtering:
    # 1. Filter out ontology roots (terms with no parents like "Disease")
    # 2. Filter out umbrella terms (high ancestor-to-direct ratio)
    # 3. Keep only terms with no ancestor in the filtered set
    def compute_display_ids(term_ids, counts, metadata)
      return [] if term_ids.empty?

      # Step 1: Filter out ontology roots (terms with no parents)
      has_parents = term_ids.select do |id|
        parent_ids = metadata.dig(id, :parent_ids) || []
        parent_ids.any?
      end
      return [] if has_parents.empty?

      # Step 2: Filter out umbrella terms (ancestor/direct ratio > threshold)
      # Terms with 0 direct datasets are kept as grouping terms (e.g., "10× 3' transcription profiling")
      not_too_generic = has_parents.select do |id|
        direct_count = counts[:direct][id] || 0
        ancestor_count = counts[:ancestor][id] || 0
        next true if direct_count == 0  # Keep as potential grouping term
        ratio = ancestor_count.to_f / direct_count
        ratio <= AGGREGATE_RATIO_THRESHOLD
      end
      return [] if not_too_generic.empty?

      # Step 3: Keep only terms with no ancestor in the filtered set
      not_too_generic_set = not_too_generic.to_set
      not_too_generic.select do |id|
        !has_ancestor_in_set?(id, not_too_generic_set, metadata)
      end
    end

    private

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
