class Organism < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_many :dataset_organisms
  has_many :datasets, through: :dataset_organisms

  validates :name, uniqueness: true

  def self.color_settings
    {
      bg_circle: "bg-blue-500",
      bg_text: "bg-blue-100",
      text_color: "text-blue-800",
    }
  end
end
