# frozen_string_literal: true

module FacetPaginationHelper
  def facet_pagination_frame_tag(category, &block)
    turbo_frame_tag(
      facet_pagination_frame_id(category),
      &block
    )
  end

  def facet_pagination_frame_id(category)
    "facet_pagination_#{category}"
  end

  def link_to_next_facet_page(category, pagination, colors: {})
    return unless pagination && pagination[:has_more]

    next_offset = pagination[:offset] + pagination[:limit]
    current_params = request.query_parameters.except(:offset, :limit, :format)

    tag.div(class: "pagination-link-container", data: { facet_pagination_target: "paginationLink" }) do
      safe_join([
        link_to(
          "Load more…",
          facet_path(category: category, offset: next_offset, limit: pagination[:limit], format: :turbo_stream, **current_params),
          class: "pagination-link block w-full py-2 px-3 text-sm text-center text-gray-500 hover:text-gray-700 hover:bg-gray-50 rounded transition-colors",
          data: {
            turbo_method: :get,
            action: "click->facet-pagination#showLoading"
          },
          "aria-label": "Load more #{Facet.find(category)&.display_name&.downcase}"
        ),
        tag.div(class: "pagination-skeleton hidden") do
          render("shared/skeleton_loader", margin_left: "0")
        end
      ])
    end
  end

  def with_facet_pagination(category, pagination, &block)
    tag.div(
      class: "facet-pagination-container",
      data: {
        controller: "facet-pagination",
        facet_pagination_category_value: category,
        facet_pagination_has_more_value: pagination&.dig(:has_more) || false
      }
    ) do
      safe_join([
        capture(&block),
        facet_pagination_frame_tag(category) do
          link_to_next_facet_page(category, pagination)
        end
      ])
    end
  end
end
