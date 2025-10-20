class DatasetsController < ApplicationController
  allow_browser versions: :modern

  def index
    search = Search::DatasetSearch.new(search_params)
    result = search.execute

    @total = result.total
    @datasets = load_datasets(result.dataset_ids)
    @facets = build_facet_views(result.facets)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def load_datasets(ids)
    return paginated_collection([]) if ids.empty?

    datasets = Dataset
      .includes(dataset_associations)
      .where(id: ids)
      .in_order_of(:id, ids)

    paginated_collection(datasets)
  end

  def build_facet_views(facet_data)
    Facets::Catalog.all.map do |config|
      {
        key: config[:key],
        type: config[:type],
        data: facet_data[config[:key].to_s] || (config[:type] == :tree ? [] : {}),
        colors: helpers.facet_color_classes(config[:key])
      }
    end
  end

  def paginated_collection(datasets)
    WillPaginate::Collection.create(current_page, items_per_page, @total || datasets.size) do |pager|
      pager.replace(datasets)
    end
  end

  def search_params
    params.except(:controller, :action, :format)
      .permit(:search, :sort, :page, :per, *permitted_facet_params)
      .merge(
        page: current_page,
        per: items_per_page,
        skip_facets: request.format.html?
      )
  end

  def permitted_facet_params
    Facets::Catalog.all.map { |f| { Facets::Catalog.param_key(f[:key]) => [] } }
  end

  def current_page
    [params[:page].to_i, 1].max
  end

  def items_per_page
    [(params[:per].presence || 6).to_i, 1].max.clamp(1, 100)
  end

  def dataset_associations
    [:sexes, :cell_types, :tissues, :developmental_stages, :organisms,
     :diseases, :technologies, :suspension_types, :file_resources,
     :study, :links, :source]
  end
end
