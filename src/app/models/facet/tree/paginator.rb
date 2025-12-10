# frozen_string_literal: true

class Facet::Tree::Paginator
  def initialize(params = {})
    @params = params
    @selected_ids = extract_all_selected_ids.to_set
  end

  def paginate(nodes, limit:, offset: 0)
    return { nodes: nodes, pagination: nil } unless limit

    sorted = sort_nodes(nodes)
    total = sorted.size

    if offset.zero?
      paginated = prioritize_selected(sorted, limit)
    else
      paginated = sorted.drop(offset).take(limit)
    end

    {
      nodes: paginated.map { |n| n.respond_to?(:to_h) ? n.to_h : n },
      pagination: {
        total: total,
        offset: offset,
        limit: limit,
        has_more: offset + limit < total
      }
    }
  end

  private
    def extract_all_selected_ids
      @params.values.flatten.compact.map(&:to_s)
    end

    def sort_nodes(nodes)
      nodes.sort_by do |node|
        relevant = relevant?(node)
        [relevant ? 0 : 1, node.name&.downcase || ""]
      end
    end

    def relevant?(node)
      @selected_ids.include?(node.id.to_s) || node.has_selected_children
    end

    def prioritize_selected(sorted_nodes, limit)
      selected = sorted_nodes.select { |n| relevant?(n) }
      non_selected = sorted_nodes.reject { |n| relevant?(n) }

      if selected.size >= limit
        selected.take(limit)
      else
        remaining_slots = limit - selected.size
        selected + non_selected.take(remaining_slots)
      end
    end
end
