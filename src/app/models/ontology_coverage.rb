class OntologyCoverage < ApplicationRecord
  self.table_name = "ontology_coverage"

  validates :source, presence: true
  validates :category, presence: true, inclusion: { in: Dataset::CATEGORIES.map(&:name) }
  validates :records, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :relationships, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :ontology_coverage, presence: true, numericality: { in: 0..100 }
  validates :source, uniqueness: { scope: :category }
end
