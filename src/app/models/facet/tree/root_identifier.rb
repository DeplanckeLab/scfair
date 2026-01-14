# frozen_string_literal: true

class Facet::Tree::RootIdentifier
  # Terms covering >90% of max are considered universal (too generic)
  UNIVERSAL_TERM_THRESHOLD = 0.9

  # Parents covering >70% of max are considered generic (shouldn't hide children)
  GENERIC_PARENT_THRESHOLD = 0.7

  # Minimum result count before applying universal term filter
  # Prevents filtering out specific terms when searching for them
  MIN_COUNT_FOR_UNIVERSAL_FILTER = 10

  def initialize(metadata)
    @metadata = metadata
  end

  def identify(term_ids, counts_by_id, direct_counts_by_id)
    return [] if term_ids.empty?

    max_count = counts_by_id.values.max || 0
    return term_ids if max_count.zero?

    candidates = filter_universal_terms(term_ids, counts_by_id, direct_counts_by_id, max_count)
    children_hidden_by_parents = build_hidden_map(
      candidates, counts_by_id, direct_counts_by_id, max_count
    )
    identify_visible_roots_iteratively(candidates, children_hidden_by_parents)
  end

  private
    def filter_universal_terms(term_ids, counts_by_id, direct_counts_by_id, max_count)
      return term_ids if max_count < MIN_COUNT_FOR_UNIVERSAL_FILTER

      universal_threshold = max_count * UNIVERSAL_TERM_THRESHOLD
      term_ids.reject do |id|
        ancestor_count = counts_by_id[id] || 0
        direct_count = direct_counts_by_id[id] || 0

        next false if direct_count > 0 && direct_count >= ancestor_count * 0.5

        ancestor_count > universal_threshold
      end
    end

    def build_hidden_map(candidates, counts_by_id, direct_counts_by_id, max_count)
      generic_threshold = max_count * GENERIC_PARENT_THRESHOLD
      candidates_set = candidates.to_set

      candidates.each_with_object({}) do |child_id, hidden_map|
        hiding_parents = find_hiding_parents(
          child_id, candidates_set, counts_by_id, direct_counts_by_id, generic_threshold
        )
        hidden_map[child_id] = hiding_parents if hiding_parents.any?
      end
    end

    def find_hiding_parents(child_id, candidates_set, counts_by_id, direct_counts_by_id, generic_threshold)
      parent_ids = @metadata.dig(child_id, :parent_ids) || []
      parents_in_set = parent_ids.select { |pid| candidates_set.include?(pid) }

      parents_in_set.select do |parent_id|
        meaningful_parent?(parent_id, child_id, counts_by_id, direct_counts_by_id, generic_threshold)
      end
    end

    def meaningful_parent?(parent_id, child_id, counts_by_id, direct_counts_by_id, generic_threshold)
      parent_count = counts_by_id[parent_id] || 0
      return false if parent_count > generic_threshold

      child_has_direct_data = (direct_counts_by_id[child_id] || 0) > 0
      parent_has_direct_data = (direct_counts_by_id[parent_id] || 0) > 0

      return false if child_has_direct_data && !parent_has_direct_data

      true
    end

    def identify_visible_roots_iteratively(candidates, children_hidden_by_parents)
      visible_roots = candidates.to_set

      loop do
        to_remove = Set.new

        children_hidden_by_parents.each do |child_id, hiding_parents|
          next unless visible_roots.include?(child_id)

          if hiding_parents.any? { |pid| visible_roots.include?(pid) }
            to_remove.add(child_id)
          end
        end

        break if to_remove.empty?

        visible_roots -= to_remove
      end

      visible_roots.to_a
    end
end
