class Disease < ApplicationRecord
  has_many :dataset_diseases
  has_many :datasets, through: :dataset_diseases

  validates :name, uniqueness: true
end
