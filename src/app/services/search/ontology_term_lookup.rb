# frozen_string_literal: true

module Search
  class OntologyTermLookup
    ONTOLOGY_INDEX = "ontology_terms"

    class << self
      def fetch_terms(term_ids)
        return {} if term_ids.empty?

        query = {
          query: { terms: { id: term_ids } },
          size: term_ids.size,
          _source: ["id", "name", "identifier", "parent_ids", "child_ids"]
        }

        response = client.search(index: ONTOLOGY_INDEX, body: query)
        hits = response.dig("hits", "hits") || []

        hits.to_h do |hit|
          source = hit["_source"]
          [
            source["id"],
            {
              name: source["name"],
              identifier: source["identifier"],
              parent_ids: source["parent_ids"] || [],
              child_ids: source["child_ids"] || []
            }
          ]
        end
      rescue => e
        Rails.logger.error("Failed to fetch ontology terms from ES: #{e.message}")
        {}
      end

      def children(parent_id)
        terms = fetch_terms([parent_id])
        terms.dig(parent_id, :child_ids) || []
      end

      def parents(child_id)
        terms = fetch_terms([child_id])
        terms.dig(child_id, :parent_ids) || []
      end

      def children_of_set(parent_ids)
        return [] if parent_ids.empty?
        terms = fetch_terms(parent_ids)
        terms.values.flat_map { |t| t[:child_ids] }.uniq
      end

      def parents_of_set(child_ids)
        return [] if child_ids.empty?
        terms = fetch_terms(child_ids)
        terms.values.flat_map { |t| t[:parent_ids] }.uniq
      end

      private

      def client
        ElasticsearchClient
      end
    end
  end
end
