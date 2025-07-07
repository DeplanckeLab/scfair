class Organism < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_and_belongs_to_many :datasets

  validates :external_reference_id, presence: true, uniqueness: true

  def self.color_settings
    {
      bg_circle: "bg-blue-500",
      bg_text: "bg-blue-100",
      text_color: "text-blue-800",
    }
  end

  def self.display_name
    "Organism"
  end

  def self.normalize_str(str)
    str.to_s.gsub(/[^A-Za-z0-9]+/, ' ').strip.downcase
  end

  def self.search_by_data(name, taxonomy_id = nil)
    normalized_name = normalize_str(name)
    pattern = "%#{normalized_name}%"

    scope = taxonomy_id.present? ? where(tax_id: taxonomy_id) : all
    if taxonomy_id.present?
      records = scope.limit(2).to_a
      raise ActiveRecord::RecordNotFound.new("No organism found with tax_id '#{taxonomy_id}'") if records.empty?
      return records.first if records.size == 1
    end

    strategies = [
      {
        query: "regexp_replace(lower(name), '[^a-z0-9]+', ' ', 'g') = :norm OR regexp_replace(lower(short_name), '[^a-z0-9]+', ' ', 'g') = :norm",
        error_message: "Multiple exact matches for '#{name}'#{taxonomy_id.present? ? " with tax_id '#{taxonomy_id}'" : ""}"
      },
      {
        query: "regexp_replace(lower(name), '[^a-z0-9]+', ' ', 'g') ILIKE :pattern",
        error_message: "Multiple partial matches on name for '#{name}'#{taxonomy_id.present? ? " with tax_id '#{taxonomy_id}'" : ""}"
      },
      {
        query: "regexp_replace(lower(short_name), '[^a-z0-9]+', ' ', 'g') ILIKE :pattern",
        error_message: "Multiple partial matches on short name for '#{name}'#{taxonomy_id.present? ? " with tax_id '#{taxonomy_id}'" : ""}"
      }
    ]

    strategies.each do |strategy|
      records = scope.where(strategy[:query], norm: normalized_name, pattern: pattern).limit(2).to_a
      return records.first if records.size == 1
      raise MultipleMatchesError.new(strategy[:error_message]) if records.size > 1
    end

    raise ActiveRecord::RecordNotFound.new("No organism found for '#{name}'#{taxonomy_id.present? ? " with tax_id '#{taxonomy_id}'" : ""}")
  end
end
