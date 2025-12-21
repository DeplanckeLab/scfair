class Technology < ApplicationRecord
  include OntologyValidated
  ALLOWED_ONTOLOGIES = %w[EFO].freeze

  belongs_to :ontology_term, optional: true

  has_and_belongs_to_many :datasets

  validates :name, uniqueness: { scope: :ontology_term_id }

  def self.color_settings
    {
      bg_circle: "bg-indigo-500",
      bg_text: "bg-indigo-100",
      text_color: "text-indigo-800",
      checkbox_checked: "text-indigo-600",
      focus_ring: "focus:ring-indigo-300"
    }
  end

  def self.display_name
    "Technology"
  end
end
