# frozen_string_literal: true

class Facet::Tree::Paginator
  def initialize(params = {}, facet: nil)
    @params = params
    @facet = facet
    @selected_ids = extract_facet_selected_ids.to_set
  end

  def ordered(nodes)
    sort_nodes(nodes)
  end

  def paginate(nodes, limit:, offset: 0)
    return { nodes: nodes, pagination: nil } unless limit

    sorted = sort_nodes(nodes)
    total = sorted.size

    paginated = if offset.zero?
                  first_page_slice(sorted, limit)
                else
                  sorted.drop(offset).take(limit)
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
    def extract_facet_selected_ids
      return [] unless @facet

      pk = @facet.param_key
      Array(@params[pk]).flatten.compact.map(&:to_s)
    end

    def first_page_slice(sorted_nodes, limit)
      disease_facet? ? sorted_nodes.take(limit) : prioritize_selected(sorted_nodes, limit)
    end

    def sort_nodes(nodes)
      nodes.sort_by do |node|
        if disease_facet?
          [healthy_disease?(node) ? 0 : 1, relevant?(node) ? 0 : 1, node.name&.downcase || ""]
        else
          [relevant?(node) ? 0 : 1, node.name&.downcase || ""]
        end
      end
    end

    def disease_facet?
      @facet&.key.to_s == "disease"
    end

    def healthy_disease?(node)
      disease_facet? && Disease.facet_healthy_control?(node.id)
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
