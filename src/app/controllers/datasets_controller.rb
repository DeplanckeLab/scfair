class DatasetsController < ApplicationController
  def index
    @search = Dataset.search do
      fulltext params[:search] if params[:search].present?
      
      adjust_solr_params do |params|
        params[:fq] = params[:fq].map do |fq|
          if fq == "type:Dataset"
            fq
          else
            field = fq.split(":").first
            "{!tag=#{field}}#{fq}"
          end
        end

        params[:"facet.field"] = params[:"facet.field"].map do |field|
          if field.include?("{!key=sex}")
            "{!ex=sexes_sm key=sex}sexes_sm"
          else
            "{!ex=#{field}}#{field}"
          end
        end
      end
      
      facet :organisms, sort: :index
      facet :cell_types, sort: :index
      facet :tissues, sort: :index
      facet :developmental_stages, sort: :index
      facet :diseases, sort: :index
      facet :sexes, name: "sex", sort: :index
      facet :technologies, sort: :index

      with(:sexes, params[:sex]) if params[:sex].present?
      with(:cell_types, params[:cell_types]) if params[:cell_types].present?
      with(:tissues, params[:tissues]) if params[:tissues].present?
      with(:developmental_stages, params[:developmental_stages]) if params[:developmental_stages].present?
      with(:organisms, params[:organisms]) if params[:organisms].present?
      with(:diseases, params[:diseases]) if params[:diseases].present?
      with(:technologies, params[:technologies]) if params[:technologies].present?
      
      paginate page: params[:page] || 1, per_page: 6

      data_accessor_for(Dataset).include = [
        :sexes,
        :cell_types,
        :tissues,
        :developmental_stages,
        :organisms,
        :diseases,
        :technologies,
        :file_resources
      ]
    end
    
    @datasets = @search.results
  end
end
