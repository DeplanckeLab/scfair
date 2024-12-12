class Sex < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_many :dataset_sexes
  has_many :datasets, through: :dataset_sexes

  validates :name, uniqueness: true
end
