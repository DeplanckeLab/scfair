module Search
  module Processors
    class FlatFacet
      def initialize(params, category)
        @params = params
        @category = category
      end

      def process(aggregation)
        return {} unless aggregation

        buckets = aggregation.dig("#{@category}_terms", "buckets") || []
        return {} if buckets.empty?

        build_facet_items(buckets)
      end

      private

      def build_facet_items(buckets)
        names_by_id = buckets.each_with_object({}) do |bucket, names|
          current_id = bucket["key"]
          source = bucket.dig("sample_doc", "hits", "hits", 0, "_source") || {}
          ids = source["#{@category}_ids"] || []
          names_list = source["#{@category}_names"] || []

          index = ids.index(current_id)
          names[current_id] = index ? names_list[index] : current_id
        end

        selected_ids = Array(@params[@category]).map(&:to_s).to_set

        buckets
          .select { |b| b["doc_count"].positive? }
          .sort_by { |b|
            id = b["key"].to_s
            name = names_by_id[id] || id
            [selected_ids.include?(id) ? 0 : 1, name.downcase]
          }
          .to_h { |b|
            name = (names_by_id[b["key"]] || b["key"]).to_s.capitalize
            [b["key"], { name: name, count: b["doc_count"] }]
          }
      end
    end
  end
end
