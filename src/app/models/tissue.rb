class Tissue < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_many :dataset_tissues
  has_many :datasets, through: :dataset_tissues

  validates :name, uniqueness: true

  def self.color_settings
    {
      bg_circle: "bg-purple-500",
      bg_text: "bg-purple-100",
      text_color: "text-purple-800",
    }
  end
end
