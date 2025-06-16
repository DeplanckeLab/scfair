class OntologyCoverage < ApplicationRecord
  self.table_name = "ontology_coverage"

  belongs_to :source

  validates :source, presence: true
  validates :category, presence: true, inclusion: { in: Dataset::CATEGORIES.map(&:name) }
  validates :source, uniqueness: { scope: :category }
end
