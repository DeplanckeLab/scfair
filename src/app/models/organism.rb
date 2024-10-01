class Organism < ApplicationRecord
  has_many :dataset_organisms
  has_many :datasets, through: :dataset_organisms

  validates :name, uniqueness: true
end
