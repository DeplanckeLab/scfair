class Technology < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_many :dataset_technologies
  has_many :datasets, through: :dataset_technologies

  validates :name, uniqueness: true

  def self.color_settings
    {
      bg_circle: "bg-indigo-500",
      bg_text: "bg-indigo-100",
      text_color: "text-indigo-800",
    }
  end
end
