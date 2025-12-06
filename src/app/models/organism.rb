class Organism < ApplicationRecord
  include OntologyValidated
  ALLOWED_ONTOLOGIES = %w[NCBITaxon].freeze

  belongs_to :ontology_term, optional: true

  has_and_belongs_to_many :datasets

  validates :name, uniqueness: { scope: :ontology_term_id }

  def self.color_settings
    {
      bg_circle: "bg-blue-500",
      bg_text: "bg-blue-100",
      text_color: "text-blue-800",
    }
  end

  def self.display_name
    "Organism"
  end
end
