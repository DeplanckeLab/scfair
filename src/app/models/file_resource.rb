class FileResource < ApplicationRecord
  VALID_FILETYPES = %w[h5ad rds tsv.gz].freeze
  
  validates :filetype, inclusion: { in: VALID_FILETYPES }
  validates :title, length: { maximum: 255 }, allow_blank: true

  def h5ad?
    filetype == "h5ad"
  end
  
  def rds?
    filetype == "rds"
  end

  def tsv_gz?
    filetype == "tsv.gz"
  end

  def dropdown_label
    formatted_filetype = filetype.to_s.downcase
    return formatted_filetype if title.blank?

    "#{title} (#{formatted_filetype})"
  end
end
