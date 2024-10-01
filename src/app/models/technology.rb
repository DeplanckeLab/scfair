class Technology < ApplicationRecord
  has_many :dataset_technologies
  has_many :datasets, through: :dataset_technologies

  validates :protocol_name, uniqueness: true
end
