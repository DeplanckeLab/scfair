class Disease < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_many :dataset_diseases
  has_many :datasets, through: :dataset_diseases

  validates :name, uniqueness: true

  def self.color_settings
    {
      bg_circle: "bg-red-500",
      bg_text: "bg-red-100",
      text_color: "text-red-800",
    }
  end
end
