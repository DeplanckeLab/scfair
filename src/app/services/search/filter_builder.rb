# frozen_string_literal: true

module Search
  class FilterBuilder
    def initialize(params)
      @params = params
    end

    def build_all
      tree_filters + flat_filters
    end

    def build_except(category)
      build_all.reject { |clause| applies_to_category?(clause, category) }
    end

    private
      def tree_filters
        Facet.tree_categories.filter_map do |category|
          build_tree_filter(category)
        end
      end

      def flat_filters
        Facet.flat_categories.filter_map do |category|
          build_flat_filter(category)
        end
      end

      def build_tree_filter(category)
        facet = Facet.find(category)
        return nil unless facet

        selected = Array(@params[facet.param_key]).reject(&:blank?)
        return nil if selected.empty?

        { terms: { "#{category}_ancestor_ids": selected } }
      end

      def build_flat_filter(category)
        facet = Facet.find(category)
        return nil unless facet

        selected = Array(@params[facet.param_key]).reject(&:blank?)
        return nil if selected.empty?

        { terms: { "#{category}_ids": selected } }
      end

      def applies_to_category?(clause, category)
        return false unless clause.key?(:terms)

        field_name = clause[:terms].keys.first.to_s
        field_name.start_with?(category.to_s)
      end
  end
end
