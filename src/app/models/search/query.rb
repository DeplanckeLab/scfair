# frozen_string_literal: true

class Search::Query
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :search, :string
  attribute :sort, :string
  attribute :page, :integer, default: 1
  attribute :per, :integer, default: 12
  attribute :skip_facets, :boolean, default: false

  # Facet filter attributes
  attribute :organisms, default: -> { [] }
  attribute :cell_types, default: -> { [] }
  attribute :tissues, default: -> { [] }
  attribute :developmental_stages, default: -> { [] }
  attribute :diseases, default: -> { [] }
  attribute :sexes, default: -> { [] }
  attribute :technologies, default: -> { [] }
  attribute :suspension_types, default: -> { [] }
  attribute :source, default: -> { [] }

  def datasets
    @datasets ||= Dataset
      .includes(*dataset_associations)
      .where(id: dataset_ids)
      .in_order_of(:id, dataset_ids)
  end

  def dataset_ids
    @dataset_ids ||= response.dig("hits", "hits")&.map { |hit| hit["_id"] } || []
  end

  def facets
    @facets ||= skip_facets ? {} : build_facets
  end

  def total
    @total ||= response.dig("hits", "total", "value") || 0
  end

  def any_filters?
    tree_filters.any? || flat_filters.any?
  end

  private
    def response
      @response ||= execute_search
    end

    def execute_search
      Search.client.search(index: Search::DATASETS_INDEX, body: elasticsearch_body)
    rescue StandardError => e
      Rails.logger.error("Search failed: #{e.class}: #{e.message}")
      { "hits" => { "hits" => [], "total" => { "value" => 0 } } }
    end

    def elasticsearch_body
      {
        query: query_clause,
        from: offset,
        size: per,
        sort: sort_clause,
        aggs: skip_facets ? {} : aggregations
      }.compact
    end

    def query_clause
      must_clauses = []
      filter_clauses = tree_filters + flat_filters

      must_clauses << search_clause if search.present?

      if must_clauses.any? || filter_clauses.any?
        {
          bool: {
            must: must_clauses.presence || [{ match_all: {} }],
            filter: filter_clauses
          }.compact
        }
      else
        { match_all: {} }
      end
    end

    def search_clause
      {
        multi_match: {
          query: search,
          fields: searchable_fields,
          type: "best_fields",
          fuzziness: 1,
          prefix_length: 2
        }
      }
    end

    def searchable_fields
      [
        # Direct hit fields - highest priority
        "title^10",
        "study_title^8",
        "description^3",
        "source_name^2",
        # Direct ontology term names - high priority for exact matches
        "organism_names^6",
        "tissue_names^5",
        "cell_types_names^5",
        "disease_names^5",
        "technology_names^4",
        "developmental_stage_names^4",
        "sex_names^3",
        "suspension_types_names^3",
        # Ancestor names - lower priority
        "organism_ancestor_names^3",
        "tissue_ancestor_names^2",
        "cell_types_ancestor_names^2",
        "disease_ancestor_names^2",
        "technology_ancestor_names^2",
        "developmental_stage_ancestor_names^2",
        "sex_ancestor_names^1"
      ]
    end

    def tree_filters
      @tree_filters ||= [].tap do |filters|
        filters << { terms: { organism_ancestor_ids: organisms } } if organisms.any?
        filters << { terms: { cell_types_ancestor_ids: cell_types } } if cell_types.any?
        filters << { terms: { tissue_ancestor_ids: tissues } } if tissues.any?
        filters << { terms: { developmental_stage_ancestor_ids: developmental_stages } } if developmental_stages.any?
        filters << { terms: { disease_ancestor_ids: diseases } } if diseases.any?
        filters << { terms: { sex_ancestor_ids: sexes } } if sexes.any?
        filters << { terms: { technology_ancestor_ids: technologies } } if technologies.any?
      end
    end

    def flat_filters
      @flat_filters ||= [].tap do |filters|
        filters << { terms: { suspension_types_ids: suspension_types } } if suspension_types.any?
        filters << { terms: { source_ids: source } } if source.any?
      end
    end

    def sort_clause
      case sort
      when "cells_asc" then [{ cell_count: :asc }, { id: :desc }]
      else [{ cell_count: :desc }, { id: :desc }]  # Default: most cells first
      end
    end

    def offset
      (page - 1) * per
    end

    def aggregations
      Facet.aggregations_for(tree_filters + flat_filters)
    end

    def build_facets
      aggregations_data = response.dig("aggregations") || {}
      Facet.process_aggregations(aggregations_data, facet_params)
    end

    def facet_params
      {
        organisms: organisms,
        cell_types: cell_types,
        tissues: tissues,
        developmental_stages: developmental_stages,
        diseases: diseases,
        sexes: sexes,
        technologies: technologies,
        suspension_types: suspension_types,
        source: source
      }
    end

    def dataset_associations
      [:sexes, :cell_types, :tissues, :developmental_stages, :organisms,
       :diseases, :technologies, :suspension_types, :file_resources,
       :study, :links, :source]
    end
end
