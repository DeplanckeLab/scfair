class Study < ApplicationRecord
  has_many :datasets, primary_key: :doi, foreign_key: :doi
end
