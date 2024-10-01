class Tissue < ApplicationRecord
  has_many :dataset_tissues
  has_many :datasets, through: :dataset_tissues

  validates :name, uniqueness: true
end
