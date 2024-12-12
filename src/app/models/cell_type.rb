class CellType < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_many :dataset_cell_types
  has_many :datasets, through: :dataset_cell_types

  validates :name, uniqueness: true
end