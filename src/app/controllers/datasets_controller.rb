class DatasetsController < ApplicationController
  def index    
    @search = Dataset.search do
      if params[:search].present?
        search_term = params[:search].split.map { |term| 
          term = Solr::Escape.escape(term.downcase) + "*"
        }.join(" AND ")
        
        fulltext search_term  do
          fields(
            text_search: 2.0,
            ancestor_ontology_terms: 0.3
          )
        end
      end
      
      adjust_solr_params do |params|
        facet_fields = %w[
          organisms_sm 
          cell_types_sm 
          tissues_sm 
          developmental_stages_sm 
          diseases_sm 
          sexes_sm 
          technologies_sm
          source_name_sm
        ]

        if params[:q] && params[:q] != "*:*"
          search_query = params[:q]
          params[:fq] = Array(params[:fq])
          params[:fq] << "{!tag=text}((text_search_text:(#{search_query})) OR (ancestor_ontology_terms_text:(#{search_query})))"
          params[:q] = "*:*"
        end

        params[:fq] = params[:fq].map do |fq|
          if fq == "type:Dataset"
            fq
          elsif fq.start_with?("{!tag=text}")
            fq
          else
            field = fq.split(":").first
            "{!tag=#{field}}#{fq}"
          end
        end

        params[:"facet.field"] = params[:"facet.field"].map do |field|
          exclusions = (facet_fields + ["text"]).join(",")
          if field.include?("{!key=sex}")
            "{!ex=#{exclusions} key=sex}sexes_sm"
          else
            "{!ex=#{exclusions}}#{field}"
          end
        end

        if params[:"facet.field"].include?("{!ex=organisms_sm,cell_types_sm,tissues_sm,developmental_stages_sm,diseases_sm,sexes_sm,technologies_sm,source_name_sm,text}organisms_sm")
          params[:"facet.field"] << "{!ex=organisms_sm,cell_types_sm,tissues_sm,developmental_stages_sm,diseases_sm,sexes_sm,technologies_sm,source_name_sm,text}organism_ancestors_sm"
        end

        params[:"facet.limit"] = -1
      end
      
      facet :organisms, sort: :count
      facet :cell_types, sort: :index
      facet :tissues, sort: :index
      facet :developmental_stages, sort: :index
      facet :diseases, sort: :index
      facet :sexes, name: "sex", sort: :index
      facet :technologies, sort: :index
      facet :source_name, sort: :index

      with(:organism_ancestors, params[:organisms]) if params[:organisms].present?
      
      with(:sexes, params[:sex]) if params[:sex].present?
      with(:cell_types, params[:cell_types]) if params[:cell_types].present?
      with(:tissues, params[:tissues]) if params[:tissues].present?
      with(:developmental_stages, params[:developmental_stages]) if params[:developmental_stages].present?
      with(:diseases, params[:diseases]) if params[:diseases].present?
      with(:technologies, params[:technologies]) if params[:technologies].present?
      with(:source_name, params[:source_name]) if params[:source_name].present?
      
      paginate page: params[:page] || 1, per_page: 6
      
      data_accessor_for(Dataset).include = [
        :sexes,
        :cell_types,
        :tissues,
        :developmental_stages,
        :organisms,
        :diseases,
        :technologies,
        :file_resources,
        :study,
        :links
      ]
    end
    
    @datasets = @search.results
    @organism_facet_rows = OrganismFacetBuilder.build_from_facets(@search) || []
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
