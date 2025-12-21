# frozen_string_literal: true

class FacetsController < ApplicationController
  allow_browser versions: :modern

  def show
    presenter = build_presenter(facet_service.load_facet(facet.key.to_s, limit: limit, offset: offset))

    respond_to do |format|
      format.html { render_html(presenter) }
      format.turbo_stream { render_turbo_stream(presenter) }
    end
  end

  def children
    data = facet_service.load_children(facet.key.to_s, params[:parent_id])
    presenter = build_presenter(data)

    respond_to do |format|
      format.html do
        render template: "facets/children",
               locals: presenter.to_children_locals(
                 parent_id: params[:parent_id],
                 frame_id: params[:frame_id]
               )
      end
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          params[:frame_id].presence || helpers.dom_id_for_nodes(facet.key.to_s, params[:parent_id]),
          partial: "facets/tree_nodes",
          locals: presenter.to_nodes_locals(level: 1, parent_id: params[:parent_id])
        )
      end
    end
  end

  def search
    data = facet_service.search_within(facet.key.to_s, params[:q])
    presenter = build_presenter(data)

    respond_to do |format|
      format.html do
        render partial: "facets/search_results",
               locals: { category: facet.key.to_s, nodes: presenter.nodes },
               layout: false
      end
      format.json { render json: { nodes: presenter.nodes } }
    end
  end

  # Expose param_key mapping for JS consumption
  # GET /facets/param_keys.json
  def param_keys
    render json: FacetSelection.param_key_map
  end

  private

    def facet
      @facet ||= Facet.find!(params[:category])
    end

    def selection
      @selection ||= FacetSelection.from_params(facet_params)
    end

    def facet_service
      @facet_service ||= Search::FacetService.new(facet_params)
    end

    def build_presenter(data)
      FacetPresenter.new(facet, data, selection)
    end

    def limit
      facet.tree? ? (params[:limit]&.to_i || 30) : nil
    end

    def offset
      params[:offset]&.to_i || 0
    end

    def pagination_request?
      params[:offset].to_i > 0
    end

    def render_html(presenter)
      if pagination_request?
        render partial: "facets/pagination_page", locals: presenter.to_pagination_locals
      else
        render partial: "facets/facet_content", locals: presenter.to_content_locals
      end
    end

    def render_turbo_stream(presenter)
      render turbo_stream: [
        turbo_stream.before(
          helpers.facet_pagination_frame_id(facet.key),
          partial: "facets/tree_nodes_batch",
          locals: presenter.to_nodes_locals(level: 0)
        ),
        turbo_stream.replace(
          helpers.facet_pagination_frame_id(facet.key),
          partial: "facets/pagination_link",
          locals: presenter.to_pagination_locals
        )
      ]
    end

    def facet_params
      params.except(:controller, :action, :category, :parent_id, :q, :format, :offset, :limit, :frame_id)
        .permit(:search, :sort, *permitted_facet_params)
    end

    def permitted_facet_params
      Facet.all.map { |f| { f.param_key => [] } }
    end
end
