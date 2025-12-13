class Sex < ApplicationRecord
  include OntologyValidated
  ALLOWED_ONTOLOGIES = %w[PATO].freeze

  belongs_to :ontology_term, optional: true

  has_and_belongs_to_many :datasets

  validates :name, uniqueness: { scope: :ontology_term_id }

  def self.color_settings
    {
      bg_circle: "bg-pink-500",
      bg_text: "bg-pink-100",
      text_color: "text-pink-800",
      checkbox_checked: "text-pink-600",
      focus_ring: "focus:ring-pink-300"
    }
  end

  def self.display_name
    "Sex"
  end
end
