class Technology < ApplicationRecord
  belongs_to :ontology_term, optional: true

  has_many :dataset_technologies
  has_many :datasets, through: :dataset_technologies

  validates :protocol_name, uniqueness: true
end
