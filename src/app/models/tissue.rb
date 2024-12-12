class Tissue < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_many :dataset_tissues
  has_many :datasets, through: :dataset_tissues

  validates :name, uniqueness: true
end
