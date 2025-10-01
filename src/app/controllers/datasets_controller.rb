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
          cell_types_facet_sm
          tissues_facet_sm
          developmental_stages_facet_sm
          diseases_facet_sm
          sexes_facet_sm
          technologies_facet_sm
          suspension_types_sm
          source_name_s
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

          if field =~ /\{!key=([^}]+)\}(.*)/
            key         = Regexp.last_match(1)
            field_name  = Regexp.last_match(2)
            "{!ex=#{exclusions} key=#{key}}#{field_name}"
          else
            "{!ex=#{exclusions}}#{field}"
          end
        end

        unless params[:"facet.field"].include?("{!ex=organisms_sm,cell_types_facet_sm,tissues_facet_sm,developmental_stages_facet_sm,diseases_facet_sm,sexes_facet_sm,technologies_facet_sm,suspension_types_sm,source_name_s,text}organism_ancestors_sm")
          params[:"facet.field"] << "{!ex=organisms_sm,cell_types_facet_sm,tissues_facet_sm,developmental_stages_facet_sm,diseases_facet_sm,sexes_facet_sm,technologies_facet_sm,suspension_types_sm,source_name_s,text}organism_ancestors_sm"
        end

        params[:"facet.limit"] = -1
      end

      facet :organisms, sort: :count
      facet :cell_types_facet, name: "cell_types", sort: :index
      facet :tissues_facet, name: "tissues", sort: :index
      facet :developmental_stages_facet, name: "developmental_stages", sort: :index
      facet :diseases_facet, name: "diseases", sort: :index
      facet :sexes_facet, name: "sex", sort: :index
      facet :technologies_facet, name: "technologies", sort: :index
      facet :suspension_types, sort: :index
      facet :source_name, sort: :index

      with(:organism_ancestors, params[:organisms]) if params[:organisms].present?

      with(:sexes_facet, params[:sex]) if params[:sex].present?
      with(:cell_types_facet, params[:cell_types]) if params[:cell_types].present?
      with(:tissues_facet, params[:tissues]) if params[:tissues].present?
      with(:developmental_stages_facet, params[:developmental_stages]) if params[:developmental_stages].present?
      with(:diseases_facet, params[:diseases]) if params[:diseases].present?
      with(:technologies_facet, params[:technologies]) if params[:technologies].present?
      with(:suspension_types, params[:suspension_types]) if params[:suspension_types].present?
      with(:source_name, params[:source_name]) if params[:source_name].present?

      if params[:sort].present?
        case params[:sort]
        when "cells_desc"
          order_by :cell_count, :desc
        when "cells_asc"
          order_by :cell_count, :asc
        end
      end

      page = params[:page].to_i
      page = 1 if page < 1
      paginate page: page, per_page: 6

      data_accessor_for(Dataset).include = [
        :sexes,
        :cell_types,
        :tissues,
        :developmental_stages,
        :organisms,
        :diseases,
        :technologies,
        :suspension_types,
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
