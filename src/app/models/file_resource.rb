class FileResource < ApplicationRecord
  FILETYPES = { "H5AD" => :h5ad, "RDS" => :rds }.freeze
  
  belongs_to :dataset

  enum filetype: { undefined: 0, h5ad: 1, rds: 2 }
end
