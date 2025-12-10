# frozen_string_literal: true

module Search
  class FacetService
    include Search::Concerns::DuplicateLabeler

    attr_reader :current_search_term

    def initialize(params = {})
      @params = params
      @query_text = params[:search].to_s.strip
    end

    def load_facet(category, limit: nil, offset: 0)
      facet = Facet.find!(category.to_sym)

      if facet.tree?
        load_facet_with_filtered_counts(category, limit: limit, offset: offset)
      else
        agg_result = fetch_filtered_aggregation(category, :flat)
        Facet::Flat.new(facet, @params).process(agg_result)
      end
    end

    def load_children(category, parent_id)
      facet = Facet.find!(category.to_sym)
      filters = filter_builder.build_except(category)
      category_excluded_query = QueryBuilder.new(@query_text, filters).build

      body = {
        size: 0,
        query: category_excluded_query,
        aggs: AggregationBuilder.build_children(category, parent_id, [])
      }

      response = client.search(index: Constants::DATASETS_INDEX, body: body)

      unfiltered_structure = fetch_unfiltered_structure(category)

      Facet::Tree.new(facet, @params).process_children(
        response.dig("aggregations", "#{category}_children"),
        parent_id: parent_id,
        visible_roots: unfiltered_structure[:visible_roots]
      )
    rescue StandardError => e
      Rails.logger.warn("Children aggregation failed: #{e.class}: #{e.message}")
      []
    end

    def search_within(category, search_term)
      facet = Facet.find!(category.to_sym)
      tree_type = facet.tree?

      @current_search_term = search_term.downcase unless tree_type

      search_clause = build_search_clause(category, search_term, tree: tree_type)
      base_query = QueryBuilder.new(@query_text, filter_builder.build_except(category)).build
      body = build_search_body(category, search_clause, base_query, tree: tree_type)
      response = client.search(index: Constants::DATASETS_INDEX, body: body)

      tree_type ? process_tree_search_results(response["aggregations"], category) :
                  process_flat_search_results(response["aggregations"], category)
    rescue StandardError => e
      Rails.logger.warn("Category search failed: #{e.class}: #{e.message}")
      []
    end

    private
      def has_selection?(category)
        facet = Facet.find(category)
        facet && @params[facet.param_key].present?
      end

      def load_facet_with_filtered_counts(category, limit: nil, offset: 0)
        facet = Facet.find!(category.to_sym)
        unfiltered_structure = fetch_unfiltered_structure(category)
        filtered_agg = fetch_filtered_aggregation(category, :tree)

        Facet::Tree.new(facet, @params).process_with_structure(
          filtered_agg,
          unfiltered_structure,
          limit: limit,
          offset: offset
        )
      end

      def fetch_unfiltered_structure(category)
        unfiltered_query = QueryBuilder.new(@query_text, []).build

        body = {
          size: 0,
          query: unfiltered_query,
          aggs: AggregationBuilder.build_for_facet(category, :tree, [])
        }

        response = client.search(index: Constants::DATASETS_INDEX, body: body)
        agg = response.dig("aggregations", "facet_#{category}")

        ancestor_buckets = agg.dig("ancestor_terms", "buckets") || []
        direct_buckets = agg.dig("direct_terms", "buckets") || []

        counts_by_id = ancestor_buckets.to_h { |b| [b["key"], b["doc_count"]] }
        direct_counts_by_id = direct_buckets.to_h { |b| [b["key"], b["doc_count"]] }
        direct_ids = direct_buckets.map { |b| b["key"] }
        ancestor_ids = ancestor_buckets.map { |b| b["key"] }

        terms_metadata = Search::OntologyTermLookup.fetch_terms((direct_ids + ancestor_ids).uniq)
        candidates = build_candidates_with_virtual_parents(direct_ids, ancestor_ids, counts_by_id, direct_counts_by_id, terms_metadata)

        root_identifier = Facet::Tree::RootIdentifier.new(terms_metadata)
        visible_roots = root_identifier.identify(candidates, counts_by_id, direct_counts_by_id)

        {
          visible_roots: visible_roots,
          terms_metadata: terms_metadata
        }
      rescue StandardError => e
        Rails.logger.warn("Unfiltered structure fetch failed: #{e.class}: #{e.message}")
        { visible_roots: [], terms_metadata: {} }
      end

      def fetch_filtered_aggregation(category, type)
        filters = filter_builder.build_all
        filtered_query = QueryBuilder.new(@query_text, filters).build
        body = {
          size: 0,
          query: filtered_query,
          aggs: AggregationBuilder.build_for_facet(category, type, [])
        }

        response = client.search(index: Constants::DATASETS_INDEX, body: body)
        response.dig("aggregations", "facet_#{category}")
      rescue StandardError => e
        Rails.logger.warn("Filtered aggregation failed: #{e.class}: #{e.message}")
        Constants::EMPTY_AGGREGATION
      end

      def fetch_aggregation(category, type)
        filters = filter_builder.build_except(category)
        category_excluded_query = QueryBuilder.new(@query_text, filters).build
        body = {
          size: 0,
          query: category_excluded_query,
          aggs: AggregationBuilder.build_for_facet(category, type, [])
        }

        response = client.search(index: Constants::DATASETS_INDEX, body: body)
        response.dig("aggregations", "facet_#{category}")
      rescue StandardError => e
        Rails.logger.warn("Facet aggregation failed: #{e.class}: #{e.message}")
        Constants::EMPTY_AGGREGATION
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
                        terms: { field: "#{category}_hierarchy.id", size: Constants::MAX_AGGREGATION_SIZE },
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
                    terms: { field: "#{category}_ids", size: Constants::MAX_AGGREGATION_SIZE },
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

      def build_candidates_with_virtual_parents(direct_ids, ancestor_ids, counts_by_id, direct_counts_by_id, terms_metadata)
        candidates = direct_ids.to_set
        ancestor_set = ancestor_ids.to_set

        direct_ids.each do |child_id|
          parent_ids = terms_metadata.dig(child_id, :parent_ids) || []
          parent_ids.each do |pid|
            next unless ancestor_set.include?(pid)
            next if candidates.include?(pid)
            next unless counts_by_id[pid].to_i > 0
            next unless direct_counts_by_id[pid].to_i > 0

            candidates.add(pid)
          end
        end

        candidates.to_a
      end
  end
end
