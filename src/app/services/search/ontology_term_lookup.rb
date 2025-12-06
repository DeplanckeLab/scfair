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

      def children(parent_id, category: nil)
        terms = fetch_terms([parent_id])
        child_ids = terms.dig(parent_id, :child_ids) || []

        return child_ids if category.nil?

        filter_by_ontology_prefix(child_ids, category)
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

      def filter_by_ontology_prefix(term_ids, category)
        return term_ids if term_ids.empty?

        allowed_prefixes = Facets::Catalog.ontology_prefixes(category)
        return term_ids if allowed_prefixes.empty?

        # Fetch term metadata to get identifiers
        terms_data = fetch_terms(term_ids)

        term_ids.select do |term_id|
          identifier = terms_data.dig(term_id, :identifier).to_s
          prefix = identifier.split(":").first
          allowed_prefixes.include?(prefix)
        end
      end

      def client
        ElasticsearchClient
      end
    end
  end
end
