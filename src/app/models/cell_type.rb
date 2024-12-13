class CellType < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_many :dataset_cell_types
  has_many :datasets, through: :dataset_cell_types

  validates :name, uniqueness: true

  def self.color_settings
    {
      bg_circle: "bg-green-500",
      bg_text: "bg-green-100",
      text_color: "text-green-800",
    }
  end
end
