# frozen_string_literal: true

module Facets
  class Catalog
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
      { key: :organism, type: :tree, model: Organism },
      { key: :cell_types, type: :tree, model: CellType },
      { key: :tissue, type: :tree, model: Tissue },
      { key: :developmental_stage, type: :tree, model: DevelopmentalStage },
      { key: :disease, type: :tree, model: Disease },
      { key: :sex, type: :tree, model: Sex },
      { key: :technology, type: :tree, model: Technology },
      { key: :suspension_types, type: :flat, model: SuspensionType },
      { key: :source, type: :flat, model: Source, association: :source }
    ].freeze

    class << self
      def all
        CONFIGURATION
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

      def find(key)
        CONFIGURATION.find { |f| f[:key] == key.to_sym }
      end

      def find!(key)
        find(key) || raise(ArgumentError, "Unknown facet: #{key}")
      end

      def type_for(key)
        find(key)&.dig(:type)
      end

      def tree?(key)
        type_for(key) == :tree
      end

      def flat?(key)
        type_for(key) == :flat
      end

      def ontology_prefixes(key)
        ONTOLOGY_PREFIXES[key.to_sym] || []
      end

      def display_name(key)
        case key.to_sym
        when :source then "Data Source"
        when :cell_types then "Cell Type"
        when :suspension_types then "Suspension Type"
        else
          key.to_s.humanize.titleize
        end
      end

      def param_key(key)
        config = find(key)
        return key if config&.dig(:type) == :flat

        key.to_sym == :organism ? :organisms : key.to_s.pluralize.to_sym
      end

      def association_name(key)
        config = find(key)
        config[:association] || key.to_s.pluralize.to_sym
      end

      def models_with_ontology
        @models_with_ontology ||= CONFIGURATION
          .select { |f| f[:type] == :tree && f[:model] }
          .map { |f| [f[:key].to_s, f[:model]] }
          .to_h
      end

      def color_settings(key)
        config = find(key)
        return default_colors unless config

        model = config[:model]
        model.respond_to?(:color_settings) ? model.color_settings : default_colors
      end

      private

      def default_colors
        {
          bg_circle: "bg-blue-500",
          bg_text: "bg-blue-100",
          text_color: "text-blue-800"
        }
      end
    end
  end
end
