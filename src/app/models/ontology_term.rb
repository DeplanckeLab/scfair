class OntologyTerm < ApplicationRecord
  has_many :sexes
  has_many :cell_types
  has_many :developmental_stages
  has_many :diseases
  has_many :organisms
  has_many :technologies
  has_many :tissues

  validates :identifier, presence: true, uniqueness: true
end
