# frozen_string_literal: true

module Search
  class DatasetSearch
    include Search::Concerns::Retryable

    Result = Struct.new(:dataset_ids, :total, :facets, keyword_init: true)

    def initialize(params = {})
      @params = params
      @query_text = params[:search].to_s.strip
      @page = [params[:page].to_i, Constants::DEFAULT_PAGE].max
      @per = [params[:per].to_i, Constants::DEFAULT_PER_PAGE].max
      @sort = params[:sort].presence
      @skip_facets = params[:skip_facets].present?
    end

    def execute
      response = perform_search

      Result.new(
        dataset_ids: extract_dataset_ids(response),
        total: extract_total_count(response),
        facets: @skip_facets ? {} : process_all_facets(extract_aggregations(response))
      )
    rescue StandardError => e
      Rails.logger.warn("Elasticsearch query failed: #{e.class}: #{e.message}")
      Result.new(dataset_ids: [], total: 0, facets: {})
    end

    private
      def perform_search
        with_retries { client.search(index: Constants::DATASETS_INDEX, body: request_body) }
      end

      def request_body
        {
          from: (@page - 1) * @per,
          size: @per,
          query: query,
          sort: sort
        }.tap do |body|
          body[:aggs] = build_all_aggregations unless @skip_facets
        end
      end

      def query
        @query ||= QueryBuilder.new(@query_text, filter_builder.build_all).build
      end

      def sort
        @sort_builder ||= SortBuilder.new(@sort, @query_text.present?).build
      end

      def build_all_aggregations
        Facet.all.each_with_object({}) do |facet, aggs|
          category = facet.key.to_s
          type = facet.tree? ? :tree : :flat
          filters = filter_builder.build_except(category)

          aggs.merge!(AggregationBuilder.build_for_facet(category, type, filters))
        end
      end

      def process_all_facets(aggregations)
        Facet.all.each_with_object({}) do |facet, result|
          key = facet.key.to_s
          agg_result = aggregations["facet_#{key}"]
          next unless agg_result

          processor = facet.tree? ?
            Facet::Tree.new(facet, @params) :
            Facet::Flat.new(facet, @params)

          result[key] = processor.process(agg_result)
        end
      end

      def filter_builder
        @filter_builder ||= FilterBuilder.new(@params)
      end

      def client
        @client ||= ElasticsearchClient
      end

      def extract_dataset_ids(response)
        response.dig("hits", "hits").to_a.map { |hit| hit["_id"] }
      end

      def extract_total_count(response)
        response.dig("hits", "total", "value").to_i
      end

      def extract_aggregations(response)
        response["aggregations"] || {}
      end
  end
end
