# frozen_string_literal: true

class FacetsController < ApplicationController
  allow_browser versions: :modern

  def show
    facet_service = Search::FacetService.new(facet_params)
    limit = tree_facet? ? (params[:limit]&.to_i || 30) : nil
    offset = params[:offset]&.to_i || 0

    facet_data = facet_service.load_facet(category.to_s, limit: limit, offset: offset)

    if append_request?
      render_append_response(facet_data)
    else
      render partial: "facets/facet_content",
             locals: { facet: build_facet_view(facet_data), pagination: extract_pagination(facet_data) }
    end
  end

  def children
    facet_service = Search::FacetService.new(facet_params)
    @nodes = facet_service.load_children(category.to_s, params[:parent_id])
    @category = category.to_s
    @parent_id = params[:parent_id]
    @level = 1
    @colors = helpers.facet_color_classes(category)

    respond_to do |format|
      format.html { render template: "facets/children" }
      format.turbo_stream do
        turbo_stream.replace(
          helpers.dom_id_for_nodes(category.to_s, params[:parent_id]),
          partial: "facets/tree_nodes",
          locals: nodes_locals(@nodes)
        )
      end
    end
  end

  def search
    facet_service = Search::FacetService.new(facet_params)
    nodes = facet_service.search_within(category.to_s, params[:q])
    @category = category.to_s
    @nodes = nodes
    @colors = helpers.facet_color_classes(category)

    respond_to do |format|
      format.html do
        render partial: "facets/search_results",
               locals: { category: @category, nodes: @nodes },
               layout: false
      end
      format.json { render json: { nodes: nodes } }
    end
  end

  private

  def category
    params[:category].to_sym
  end

  def facet_config
    @facet_config ||= Facets::Catalog.find!(category)
  end

  def tree_facet?
    facet_config[:type] == :tree
  end

  def append_request?
    request.xhr? && params[:offset].to_i > 0
  end

  def render_append_response(facet_data)
    pagination = extract_pagination(facet_data)
    nodes = facet_data.is_a?(Hash) && facet_data[:nodes] ? facet_data[:nodes] : []

    response.headers["X-Has-More"] = pagination[:has_more].to_s
    response.headers["X-Total-Count"] = pagination[:total].to_s

    render partial: "facets/tree_nodes_batch",
           locals: {
             category: category.to_s,
             nodes: nodes,
             colors: helpers.facet_color_classes(category)
           }
  end

  def extract_pagination(data)
    return nil unless data.is_a?(Hash) && data[:pagination]

    data[:pagination]
  end

  def build_facet_view(data)
    # Tree facets return {nodes: [...], pagination: {...}}, flat facets return a hash directly
    actual_data = data.is_a?(Hash) && data[:nodes] ? data[:nodes] : data

    {
      key: category,
      type: facet_config[:type],
      data: actual_data,
      colors: helpers.facet_color_classes(category)
    }
  end

  def nodes_locals(nodes)
    {
      category: category.to_s,
      parent_id: params[:parent_id],
      nodes: nodes,
      level: 1,
      colors: helpers.facet_color_classes(category)
    }
  end

  def facet_params
    params.except(:controller, :action, :category, :parent_id, :q, :format, :offset, :limit)
      .permit(:search, :sort, *permitted_facet_params)
  end

  def permitted_facet_params
    Facets::Catalog.all.map { |f| { Facets::Catalog.param_key(f[:key]) => [] } }
  end
end
