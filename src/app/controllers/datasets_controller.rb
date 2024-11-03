class DatasetsController < ApplicationController
  def index
    @search = Dataset.search do
      fulltext params[:search] if params[:search].present?
      
      facet :sexes, name: "sex"
      facet :cell_types
      facet :tissues
      facet :developmental_stages
      facet :organisms
      facet :diseases
      facet :technologies

      with(:sexes, params[:sex]) if params[:sex].present?
      with(:cell_types, params[:cell_types]) if params[:cell_types].present?
      with(:tissues, params[:tissues]) if params[:tissues].present?
      with(:developmental_stages, params[:developmental_stages]) if params[:developmental_stages].present?
      with(:organisms, params[:organisms]) if params[:organisms].present?
      with(:diseases, params[:diseases]) if params[:diseases].present?
      with(:technologies, params[:technologies]) if params[:technologies].present?
      
      paginate page: params[:page] || 1, per_page: 7
    end
    
    @datasets = @search.results
  end
end
