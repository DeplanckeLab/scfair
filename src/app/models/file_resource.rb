class FileResource < ApplicationRecord
  VALID_FILETYPES = %w[h5ad rds].freeze
  
  validates :filetype, inclusion: { in: VALID_FILETYPES }
  
  scope :h5ad_files, -> { where(filetype: "h5ad") }
  scope :rds_files, -> { where(filetype: "rds") }
  
  def h5ad?
    filetype == "h5ad"
  end
  
  def rds?
    filetype == "rds"
  end
end
