# frozen_string_literal: true

class FacetsController < ApplicationController
  allow_browser versions: :modern

  def show
    facet_service = Search::FacetService.new(facet_params)
    facet_data = facet_service.load_facet(category.to_s)

    render partial: "facets/facet_content",
           locals: { facet: build_facet_view(facet_data) }
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

  def build_facet_view(data)
    {
      key: category,
      type: facet_config[:type],
      data: data,
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
    params.except(:controller, :action, :category, :parent_id, :q, :format)
      .permit(:search, :sort, *permitted_facet_params)
  end

  def permitted_facet_params
    Facets::Catalog.all.map { |f| { Facets::Catalog.param_key(f[:key]) => [] } }
  end
end
