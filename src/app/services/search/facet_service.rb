# frozen_string_literal: true

module Search
  class FacetService
    include Search::Concerns::DuplicateLabeler

    MAX_AGGREGATION_SIZE = 10_000
    attr_reader :current_search_term

    def initialize(params = {})
      @params = params
      @query_text = params[:search].to_s.strip
    end

    def load_facet(category)
      config = Facets::Catalog.find!(category.to_sym)

      agg_result = fetch_aggregation(category, config[:type])
      processor = config[:type] == :tree ?
        Processors::TreeFacet.new(@params, category) :
        Processors::FlatFacet.new(@params, category)

      processor.process(agg_result)
    end

    def load_children(category, parent_id)
      body = {
        size: 0,
        query: query,
        aggs: AggregationBuilder.build_children(category, parent_id, filter_builder.build_except(category))
      }

      response = client.search(index: "datasets", body: body)
      Processors::TreeFacet.new(@params, category).process_children(response["aggregations"], parent_id)
    rescue StandardError => e
      Rails.logger.warn("Children aggregation failed: #{e.class}: #{e.message}")
      []
    end

    def search_within(category, search_term)
      config = Facets::Catalog.find!(category.to_sym)
      is_tree = config[:type] == :tree

      @current_search_term = search_term.downcase unless is_tree

      search_clause = build_search_clause(category, search_term, tree: is_tree)
      base_query = QueryBuilder.new(@query_text, filter_builder.build_except(category)).build
      body = build_search_body(category, search_clause, base_query, tree: is_tree)
      response = client.search(index: "datasets", body: body)

      is_tree ? process_tree_search_results(response["aggregations"], category) :
                process_flat_search_results(response["aggregations"], category)
    rescue StandardError => e
      Rails.logger.warn("Category search failed: #{e.class}: #{e.message}")
      []
    end

    private

    def fetch_aggregation(category, type)
      filters = filter_builder.build_except(category)
      body = {
        size: 0,
        query: query,
        aggs: AggregationBuilder.build_for_facet(category, type, filters)
      }

      response = client.search(index: "datasets", body: body)
      response.dig("aggregations", "facet_#{category}")
    rescue StandardError => e
      Rails.logger.warn("Facet aggregation failed: #{e.class}: #{e.message}")
      type == :tree ? [] : {}
    end

    def build_search_clause(category, search_term, tree:)
      if tree
        {
          bool: {
            should: [
              { prefix: { "#{category}_hierarchy.name.keyword": { value: search_term, case_insensitive: true } } },
              { match: { "#{category}_hierarchy.name": { query: search_term, fuzziness: "AUTO" } } }
            ],
            minimum_should_match: 1
          }
        }
      else
        {
          bool: {
            should: [
              { match_phrase_prefix: { "#{category}_names": { query: search_term } } },
              { match: { "#{category}_names": { query: search_term, fuzziness: "AUTO" } } }
            ],
            minimum_should_match: 1
          }
        }
      end
    end

    def build_search_body(category, search_clause, base_query, tree:)
      if tree
        {
          size: 0,
          query: {
            bool: {
              must: [
                base_query,
                { nested: { path: "#{category}_hierarchy", query: search_clause } }
              ]
            }
          },
          aggs: {
            "matching_#{category}" => {
              nested: { path: "#{category}_hierarchy" },
              aggs: {
                filtered: {
                  filter: search_clause,
                  aggs: {
                    nodes: {
                      terms: { field: "#{category}_hierarchy.id", size: MAX_AGGREGATION_SIZE },
                      aggs: {
                        details: {
                          reverse_nested: {},
                          aggs: { sample: { top_hits: { size: 1, _source: ["#{category}_hierarchy"] } } }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      else
        {
          size: 0,
          query: { bool: { must: [base_query, search_clause] } },
          aggs: {
            "matching_#{category}" => {
              filter: search_clause,
              aggs: {
                nodes: {
                  terms: { field: "#{category}_ids", size: MAX_AGGREGATION_SIZE },
                  aggs: {
                    sample_doc: { top_hits: { size: 1, _source: ["#{category}_ids", "#{category}_names"] } }
                  }
                }
              }
            }
          }
        }
      end
    end

    def process_tree_search_results(agg, category)
      buckets = agg.dig("matching_#{category}", "filtered", "nodes", "buckets") || []
      return [] if buckets.empty?

      term_ids = buckets.map { |b| b["key"] }
      terms_metadata = OntologyTermLookup.fetch_terms(term_ids)

      results = buckets.map do |bucket|
        source = bucket.dig("details", "sample", "hits", "hits", 0, "_source") || {}
        hierarchy = source["#{category}_hierarchy"] || []
        matching = hierarchy.find { |h| h["id"] == bucket["key"] } || {}
        name = (terms_metadata.dig(bucket["key"], :name) || matching["name"] || bucket["key"]).to_s.capitalize

        {
          id: bucket["key"],
          name: name,
          identifier: terms_metadata.dig(bucket["key"], :identifier),
          count: bucket["doc_count"],
          depth: matching["depth"],
          is_direct: matching["is_direct"]
        }
      end

      label_duplicates(results) { |result| result[:identifier] }
    end

    def process_flat_search_results(agg, category)
      buckets = agg.dig("matching_#{category}", "nodes", "buckets") || []

      buckets.filter_map do |bucket|
        current_id = bucket["key"]
        source = bucket.dig("sample_doc", "hits", "hits", 0, "_source") || {}
        ids = source["#{category}_ids"] || []
        names = source["#{category}_names"] || []

        index = ids.index(current_id)
        name = (index ? names[index] : current_id).to_s.capitalize

        next unless name_matches_search?(name, @current_search_term)

        {
          id: current_id,
          name: name,
          count: bucket["doc_count"],
          depth: nil,
          is_direct: true
        }
      end
    end

    def name_matches_search?(name, search_term)
      return true unless search_term

      name_lower = name.to_s.downcase
      search_lower = search_term.to_s.downcase

      return true if name_lower.start_with?(search_lower)
      return true if name_lower.include?(search_lower)

      words = name_lower.split(/\s+/)
      words.any? { |word| word.start_with?(search_lower) }
    end

    def query
      @query ||= QueryBuilder.new(@query_text, filter_builder.build_all).build
    end

    def filter_builder
      @filter_builder ||= FilterBuilder.new(@params)
    end

    def client
      @client ||= ElasticsearchClient
    end
  end
end
