class Disease < ApplicationRecord
  include OntologyValidated
  ALLOWED_ONTOLOGIES = %w[MONDO].freeze
  # PATO:0000461 = normal / healthy (non-disease) samples; surfaced first in the disease facet.
  HEALTHY_PATO_IDENTIFIER = "PATO:0000461".freeze
  HEALTHY_FACET_LABEL = "Normal (healthy)".freeze
  ALLOWED_SPECIAL_IDENTIFIERS = [HEALTHY_PATO_IDENTIFIER].freeze

  belongs_to :ontology_term, optional: true

  has_and_belongs_to_many :datasets

  validates :name, uniqueness: { scope: :ontology_term_id }

  def self.color_settings
    {
      bg_circle: "bg-red-500",
      bg_text: "bg-red-100",
      text_color: "text-red-800",
      checkbox_checked: "text-red-600",
      focus_ring: "focus:ring-red-300"
    }
  end

  def self.display_name
    "Disease"
  end

  def self.facet_healthy_control?(ontology_term_id)
    healthy_ontology_term_ids.include?(ontology_term_id.to_s)
  end

  def self.healthy_ontology_term_ids
    Rails.cache.fetch("disease/healthy_ontology_term_ids", expires_in: 1.hour) do
      OntologyTerm.where(identifier: HEALTHY_PATO_IDENTIFIER).pluck(:id).map(&:to_s).to_set
    end
  end
end
