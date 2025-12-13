# frozen_string_literal: true

class Facet
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Ontology prefixes that are valid for each category
  # Children with other prefixes will be filtered out during tree navigation
  ONTOLOGY_PREFIXES = {
    organism: %w[NCBITaxon],
    cell_types: %w[CL FBbt],
    tissue: %w[UBERON FBbt CL],
    developmental_stage: %w[HsapDv MmusDv FBdv ZFS UBERON],
    disease: %w[MONDO PATO],
    sex: %w[PATO],
    technology: %w[EFO]
  }.freeze

  CONFIGURATION = [
    { key: :organism, type: :tree, model: "Organism" },
    { key: :cell_types, type: :tree, model: "CellType" },
    { key: :tissue, type: :tree, model: "Tissue" },
    { key: :developmental_stage, type: :tree, model: "DevelopmentalStage" },
    { key: :disease, type: :tree, model: "Disease" },
    { key: :sex, type: :tree, model: "Sex" },
    { key: :technology, type: :tree, model: "Technology" },
    { key: :suspension_types, type: :flat, model: "SuspensionType" },
    { key: :source, type: :flat, model: "Source", association: :source }
  ].freeze

  attribute :key, :string

  class << self
    def all
      CONFIGURATION.map { |config| new(key: config[:key]) }
    end

    def find(key)
      config = find_config(key)
      config ? new(key: config[:key]) : nil
    end

    def find!(key)
      find(key) || raise(ArgumentError, "Unknown facet: #{key}")
    end

    def tree_categories
      @tree_categories ||= CONFIGURATION
        .select { |f| f[:type] == :tree }
        .map { |f| f[:key].to_s }
    end

    def flat_categories
      @flat_categories ||= CONFIGURATION
        .select { |f| f[:type] == :flat }
        .map { |f| f[:key].to_s }
    end

    def aggregations_for(filters)
      CONFIGURATION.each_with_object({}) do |config, aggs|
        category = config[:key]
        type = config[:type]
        aggs.merge!(build_aggregation(category, type, filters))
      end
    end

    def process_aggregations(aggregations_data, params = {})
      CONFIGURATION.each_with_object({}) do |config, results|
        category = config[:key].to_s
        facet = find(category)
        aggregation = aggregations_data["facet_#{category}"]

        results[category] = facet.process_aggregation(aggregation, params) if aggregation
      end
    end

    def ontology_prefixes(key)
      ONTOLOGY_PREFIXES[key.to_sym] || []
    end

    def models_with_ontology
      @models_with_ontology ||= CONFIGURATION
        .select { |f| f[:type] == :tree && f[:model] }
        .map { |f| [f[:key].to_s, f[:model].constantize] }
        .to_h
    end

    private
      def find_config(key)
        CONFIGURATION.find { |f| f[:key] == key.to_sym }
      end

      def build_aggregation(category, type, filters)
        filter_clause = filters.any? ? { bool: { must: filters } } : { match_all: {} }

        if type == :tree
          build_tree_aggregation(category, filter_clause)
        else
          build_flat_aggregation(category, filter_clause)
        end
      end

      def build_tree_aggregation(category, filter_clause)
        {
          "facet_#{category}" => {
            filter: filter_clause,
            aggs: {
              ancestor_terms: {
                terms: { field: "#{category}_ancestor_ids", size: Search::MAX_AGGREGATION_SIZE, min_doc_count: 1 }
              },
              direct_terms: {
                terms: { field: "#{category}_ids", size: Search::MAX_AGGREGATION_SIZE, min_doc_count: 1 }
              }
            }
          }
        }
      end

      def build_flat_aggregation(category, filter_clause)
        {
          "facet_#{category}" => {
            filter: filter_clause,
            aggs: {
              "#{category}_terms" => {
                terms: { field: "#{category}_ids", size: Search::MAX_AGGREGATION_SIZE, min_doc_count: 1 },
                aggs: {
                  sample_doc: {
                    top_hits: {
                      size: 1,
                      _source: ["#{category}_ids", "#{category}_names"]
                    }
                  }
                }
              }
            }
          }
        }
      end
  end

  def config
    @config ||= CONFIGURATION.find { |f| f[:key] == key.to_sym }
  end

  def tree?
    config[:type] == :tree
  end

  def flat?
    config[:type] == :flat
  end

  def model
    @model ||= config[:model].constantize
  end

  def display_name
    case key.to_sym
    when :source then "Data Source"
    when :cell_types then "Cell Type"
    when :suspension_types then "Suspension Type"
    else
      key.to_s.humanize.titleize
    end
  end

  def param_key
    return key.to_sym if flat?
    key.to_sym == :organism ? :organisms : key.to_s.pluralize.to_sym
  end

  def association_name
    config[:association] || key.to_s.pluralize.to_sym
  end

  def color_settings
    return default_colors unless model.respond_to?(:color_settings)
    model.color_settings
  end

  def process_aggregation(aggregation, params = {})
    return [] unless aggregation

    if tree?
      Facet::Tree.new(self, params).process(aggregation)
    else
      Facet::Flat.new(self).process(aggregation)
    end
  end

  private
    def default_colors
      {
        bg_circle: "bg-blue-500",
        bg_text: "bg-blue-100",
        text_color: "text-blue-800",
        checkbox_checked: "text-blue-600",
        focus_ring: "focus:ring-blue-300"
      }
    end
end
