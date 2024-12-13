class DevelopmentalStage < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_many :dataset_developmental_stages
  has_many :datasets, through: :dataset_developmental_stages

  validates :name, uniqueness: true

  def self.color_settings
    {
      bg_circle: "bg-orange-500",
      bg_text: "bg-orange-100",
      text_color: "text-orange-800",
    }
  end
end
