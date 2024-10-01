class DevelopmentalStage < ApplicationRecord
  has_many :dataset_developmental_stages
  has_many :datasets, through: :dataset_developmental_stages

  validates :name, uniqueness: true
end
