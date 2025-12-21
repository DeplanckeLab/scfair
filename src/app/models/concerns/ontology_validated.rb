# frozen_string_literal: true

module OntologyValidated
  extend ActiveSupport::Concern

  class_methods do
    def valid_ontology?(identifier)
      return false if identifier.blank?

      # Check special identifiers first (e.g., Disease's PATO:0000461)
      return true if allowed_special_identifiers.include?(identifier)

      prefix = extract_ontology_prefix(identifier)
      allowed_ontologies.include?(prefix)
    end

    def extract_ontology_prefix(identifier)
      str = identifier.to_s

      # Handle Cellosaurus format (CVCL_XXXX uses underscore separator)
      return "Cellosaurus" if str.start_with?("CVCL_")

      # Standard colon-separated format (PREFIX:ID)
      prefix = str.split(':').first

      # Normalize NCBITaxon case variations (NCBItaxon, NCBITAXON -> NCBITaxon)
      return "NCBITaxon" if prefix&.downcase == "ncbitaxon"

      prefix
    end

    def allowed_ontologies
      defined?(self::ALLOWED_ONTOLOGIES) ? self::ALLOWED_ONTOLOGIES : []
    end

    def allowed_special_identifiers
      defined?(self::ALLOWED_SPECIAL_IDENTIFIERS) ? self::ALLOWED_SPECIAL_IDENTIFIERS : []
    end
  end
end
