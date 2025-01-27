class Organism < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_and_belongs_to_many :datasets

  validates :name, uniqueness: true
  validates :short_name, uniqueness: true

  def self.color_settings
    {
      bg_circle: "bg-blue-500",
      bg_text: "bg-blue-100",
      text_color: "text-blue-800",
    }
  end

  def self.search_by_name(term)
    exact_match = where("name = ?", term).first
    return exact_match if exact_match

    fuzzy_matches = where("name ILIKE ?", "%#{term}%").limit(2)
    raise MultipleMatchesError.new(term) if fuzzy_matches.size > 1

    fuzzy_matches.first
  end

  def self.search_by_short_name(term)
    exact_match = where("short_name = ?", term).first
    return exact_match if exact_match

    fuzzy_matches = where("short_name ILIKE ?", "%#{term}%").limit(2)
    raise MultipleMatchesError.new(term) if fuzzy_matches.size > 1

    fuzzy_matches.first
  end
end
