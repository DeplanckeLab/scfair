class SuspensionType < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_and_belongs_to_many :datasets

  validates :name, presence: true, uniqueness: true

  def self.requires_ontology_link?
    false
  end

  def self.color_settings
    {
      bg_circle: "bg-teal-500",
      bg_text: "bg-teal-100",
      text_color: "text-teal-800",
    }
  end

  def self.display_name
    "Suspension Type"
  end
end
