# frozen_string_literal: true

module Search
  class AggregationBuilder
    class << self
      def build_for_facet(category, type, filters)
        new(category, filters).send("build_#{type}_aggregation")
      end

      def build_children(category, parent_id, filters)
        new(category, filters).build_children_aggregation(parent_id)
      end
    end

    def initialize(category, filters = [])
      @category = category
      @filters = filters
    end

    def build_tree_aggregation
      {
        "facet_#{@category}" => facet_aggregation_structure
      }
    end

    def build_flat_aggregation
      {
        "facet_#{@category}" => {
          filter: filter_clause,
          aggs: {
            "#{@category}_terms" => {
              terms: { field: "#{@category}_ids", size: Constants::MAX_AGGREGATION_SIZE, min_doc_count: 1 },
              aggs: {
                sample_doc: {
                  top_hits: {
                    size: 1,
                    _source: ["#{@category}_ids", "#{@category}_names"]
                  }
                }
              }
            }
          }
        }
      }
    end

    def build_children_aggregation(parent_id)
      key = parent_id ? "#{@category}_children" : "#{@category}_roots"
      term_key = parent_id ? "children_terms" : "root_terms"

      base = {
        filter: filter_clause,
        aggs: {
          term_key => {
            terms: { field: "#{@category}_ancestor_ids", size: Constants::MAX_AGGREGATION_SIZE, min_doc_count: 1 }
          },
          direct_terms: {
            terms: { field: "#{@category}_ids", size: Constants::MAX_AGGREGATION_SIZE, min_doc_count: 1 }
          }
        }
      }

      if parent_id
        child_ids = OntologyTermLookup.children(parent_id, category: @category)
        base[:aggs][term_key][:terms][:include] = child_ids.map(&:to_s)
      end

      { key => base }
    end

    private
      def facet_aggregation_structure
        {
          filter: filter_clause,
          aggs: {
            ancestor_terms: {
              terms: { field: "#{@category}_ancestor_ids", size: Constants::MAX_AGGREGATION_SIZE, min_doc_count: 1 }
            },
            direct_terms: {
              terms: { field: "#{@category}_ids", size: Constants::MAX_AGGREGATION_SIZE, min_doc_count: 1 }
            }
          }
        }
      end

      def filter_clause
        @filters.any? ? { bool: { must: @filters } } : { match_all: {} }
      end
  end
end
