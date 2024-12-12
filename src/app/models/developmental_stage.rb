class DevelopmentalStage < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_many :dataset_developmental_stages
  has_many :datasets, through: :dataset_developmental_stages

  validates :name, uniqueness: true
end
