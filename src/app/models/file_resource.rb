class FileResource < ApplicationRecord
  belongs_to :dataset

  enum filetype: { undefined: 0, h5ad: 1, rds: 2 }
end
