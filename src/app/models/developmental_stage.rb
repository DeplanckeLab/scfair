class DevelopmentalStage < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_and_belongs_to_many :datasets

  validates :name, uniqueness: { scope: :ontology_term_id }

  def self.color_settings
    {
      bg_circle: "bg-orange-500",
      bg_text: "bg-orange-100",
      text_color: "text-orange-800",
    }
  end
end
