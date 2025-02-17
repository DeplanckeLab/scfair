class FileResource < ApplicationRecord
  VALID_FILETYPES = %w[h5ad rds tsv.gz].freeze
  
  validates :filetype, inclusion: { in: VALID_FILETYPES }

  def h5ad?
    filetype == "h5ad"
  end
  
  def rds?
    filetype == "rds"
  end

  def tsv_gz?
    filetype == "tsv.gz"
  end
end
