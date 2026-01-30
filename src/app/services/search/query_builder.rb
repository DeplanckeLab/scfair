# frozen_string_literal: true

module Search
  class QueryBuilder
    def initialize(query_text, filters)
      @query_text = query_text
      @filters = filters
    end

    def build
      @query_text.present? ? search_query : browse_query
    end

    private
      def search_query
        {
          bool: {
            must: multi_match_query,
            filter: base_filters + @filters
          }
        }
      end

      def browse_query
        all_filters = base_filters + @filters
        all_filters.any? ? { bool: { filter: all_filters } } : { match_all: {} }
      end

      def base_filters
        [
          { term: { status: "completed" } }
        ]
      end

      def multi_match_query
        {
          multi_match: {
            query: @query_text,
            type: "best_fields",
            fields: searchable_fields
          }
        }
      end

      def searchable_fields
        [
          "text_search^1.0",
          "organism_names^5.0",
          "tissue_names^5.0",
          "cell_type_names^5.0",
          "developmental_stage_names^5.0",
          "disease_names^5.0",
          "sex_names^5.0",
          "technology_names^5.0",
          "organism_synonyms^5.0",
          "tissue_synonyms^5.0",
          "developmental_stage_synonyms^5.0",
          "disease_synonyms^5.0",
          "sex_synonyms^5.0",
          "technology_synonyms^5.0",
          "cell_type_synonyms^5.0",
          "organism_ancestor_names^2.0",
          "tissue_ancestor_names^2.0",
          "cell_type_ancestor_names^2.0",
          "developmental_stage_ancestor_names^2.0",
          "disease_ancestor_names^2.0",
          "sex_ancestor_names^2.0",
          "technology_ancestor_names^2.0"
        ]
      end
  end
end
