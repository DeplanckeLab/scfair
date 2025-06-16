class Technology < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_and_belongs_to_many :datasets

  validates :name, uniqueness: { scope: :ontology_term_id }

  def self.color_settings
    {
      bg_circle: "bg-indigo-500",
      bg_text: "bg-indigo-100",
      text_color: "text-indigo-800",
    }
  end

  def self.name
    "Technology"
  end
end
