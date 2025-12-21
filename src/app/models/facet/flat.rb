# frozen_string_literal: true

class Facet::Flat
  def initialize(facet, params = {})
    @facet = facet
    @params = params
    @category = facet.key.to_s
    @selected_ids = extract_selected_ids.to_set
  end

  def process(aggregation)
    return [] unless aggregation

    buckets = aggregation.dig("#{@category}_terms", "buckets") || []
    return [] if buckets.empty?

    names_by_id = extract_names(buckets)
    nodes = build_nodes(buckets, names_by_id)
    sorted = sort_nodes(nodes)

    sorted.map(&:to_h)
  end

  private
    def extract_selected_ids
      param_key = @facet.param_key
      Array(@params[param_key]).map(&:to_s)
    end

    def extract_names(buckets)
      buckets.each_with_object({}) do |bucket, names|
        current_id = bucket["key"]
        source = bucket.dig("sample_doc", "hits", "hits", 0, "_source") || {}
        ids = source["#{@category}_ids"] || []
        names_list = source["#{@category}_names"] || []

        index = ids.index(current_id)
        names[current_id] = index ? names_list[index] : current_id
      end
    end

    def build_nodes(buckets, names_by_id)
      buckets
        .select { |b| b["doc_count"].positive? }
        .map { |bucket| build_node(bucket, names_by_id) }
    end

    def build_node(bucket, names_by_id)
      id = bucket["key"]
      raw_name = names_by_id[id] || id
      name = raw_name.to_s.capitalize

      FacetNode.new(
        id: id,
        name: name,
        count: bucket["doc_count"],
        has_children: false,
        has_selected_children: false
      )
    end

    def sort_nodes(nodes)
      nodes.sort_by do |node|
        selected = @selected_ids.include?(node.id.to_s)
        [selected ? 0 : 1, node.name&.downcase || ""]
      end
    end
end
