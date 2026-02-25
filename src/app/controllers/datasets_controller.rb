class DatasetsController < ApplicationController
  allow_browser versions: :modern

  def index
    @result = Search::DatasetSearch.new(search_params).execute
    @total = @result.total
    @datasets = paginated_datasets
    @facets = build_facet_views

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def download_file
    dataset = Dataset.includes(:source).find(params[:id])
    resource = dataset.file_resources.find(params[:file_resource_id])

    unless dataset.source&.slug == "bgee" && resource.h5ad?
      redirect_to resource.url, allow_other_host: true
      return
    end

    download = Datasets::FileDownloadProxy.new(resource: resource).call
    if download.success?
      send_data(
        download.body,
        filename: download.filename,
        type: download.content_type,
        disposition: "attachment"
      )
    else
      head download.http_status
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
  private
    def paginated_datasets
      WillPaginate::Collection.create(current_page, items_per_page, @total) do |pager|
        pager.replace(load_datasets)
      end
    end

    def load_datasets
      return [] if @result.dataset_ids.empty?

      Dataset
        .includes(*dataset_associations)
        .where(id: @result.dataset_ids)
        .in_order_of(:id, @result.dataset_ids)
    end

    def dataset_associations
      [:sexes, :cell_types, :tissues, :developmental_stages, :organisms,
       :diseases, :technologies, :suspension_types, :file_resources,
       :study, :links, :source]
    end

    def build_facet_views
      Facet.all.map do |facet|
        {
          key: facet.key.to_sym,
          type: facet.tree? ? :tree : :flat,
          data: @result.facets[facet.key.to_s] || (facet.tree? ? [] : {}),
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
