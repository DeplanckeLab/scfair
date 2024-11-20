class DatasetLink < ApplicationRecord
  belongs_to :dataset, counter_cache: true

  validates :url, presence: true
  validates :url, uniqueness: { scope: :dataset_id }
  validate :valid_url_format

  private

  def valid_url_format
    uri = URI.parse(url)
    errors.add(:url, "must be a valid URL") unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    errors.add(:url, "must be a valid URL")
  end
end 