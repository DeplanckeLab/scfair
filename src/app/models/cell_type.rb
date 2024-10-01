class CellType < ApplicationRecord
  has_many :dataset_cell_types
  has_many :datasets, through: :dataset_cell_types

  validates :name, uniqueness: true
end