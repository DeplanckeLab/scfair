class Disease < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_many :dataset_diseases
  has_many :datasets, through: :dataset_diseases

  validates :name, uniqueness: true
end
