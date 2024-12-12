class Organism < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_many :dataset_organisms
  has_many :datasets, through: :dataset_organisms

  validates :name, uniqueness: true
end
