class Disease < ApplicationRecord
  include OntologyValidated
  ALLOWED_ONTOLOGIES = %w[MONDO].freeze
  ALLOWED_SPECIAL_IDENTIFIERS = %w[PATO:0000461].freeze  # PATO:0000461 = "normal/healthy"

  belongs_to :ontology_term, optional: true

  has_and_belongs_to_many :datasets

  validates :name, uniqueness: { scope: :ontology_term_id }

  def self.color_settings
    {
      bg_circle: "bg-red-500",
      bg_text: "bg-red-100",
      text_color: "text-red-800",
    }
  end

  def self.display_name
    "Disease"
  end
end
