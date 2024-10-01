class Sex < ApplicationRecord
  has_many :dataset_sexes
  has_many :datasets, through: :dataset_sexes

  validates :name, uniqueness: true
end
