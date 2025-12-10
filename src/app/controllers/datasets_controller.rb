class DatasetsController < ApplicationController
  allow_browser versions: :modern

  def index
    @query = Search::Query.new(search_params)
    @total = @query.total
    @datasets = paginated_datasets
    @facets = build_facet_views

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private
    def paginated_datasets
      WillPaginate::Collection.create(current_page, items_per_page, @total) do |pager|
        pager.replace(@query.datasets)
      end
    end

    def build_facet_views
      Facet.all.map do |facet|
        {
          key: facet.key.to_sym,
          type: facet.tree? ? :tree : :flat,
          data: @query.facets[facet.key.to_s] || (facet.tree? ? [] : {}),
          colors: helpers.facet_color_classes(facet.key)
        }
      end
    end

    def search_params
      params.except(:controller, :action, :format)
        .permit(:search, :sort, :page, :per, *permitted_facet_params)
        .to_h
        .symbolize_keys
        .merge(
          page: current_page,
          per: items_per_page,
          skip_facets: request.format.html?
        )
    end

    def permitted_facet_params
      Facet.all.map { |f| { f.param_key => [] } }
    end

    def current_page
      [params[:page].to_i, 1].max
    end

    def items_per_page
      [(params[:per].presence || 6).to_i, 1].max.clamp(1, 100)
    end
end
