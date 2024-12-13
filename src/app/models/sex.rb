class Sex < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_many :dataset_sexes
  has_many :datasets, through: :dataset_sexes

  validates :name, uniqueness: true

  def self.color_settings
    {
      bg_circle: "bg-pink-500",
      bg_text: "bg-pink-100",
      text_color: "text-pink-800",
    }
  end
end
