class Tissue < ApplicationRecord
  include OntologyValidated
  # UBERON (general), Cellosaurus, CL + organism-specific: WBbt (worm), ZFA (zebrafish), FBbt (fly)
  ALLOWED_ONTOLOGIES = %w[UBERON Cellosaurus CL WBbt ZFA FBbt].freeze

  belongs_to :ontology_term, optional: true

  has_and_belongs_to_many :datasets

  validates :name, uniqueness: { scope: :ontology_term_id }

  def self.color_settings
    {
      bg_circle: "bg-purple-500",
      bg_text: "bg-purple-100",
      text_color: "text-purple-800",
    }
  end

  def self.display_name
    "Tissue"
  end
end
