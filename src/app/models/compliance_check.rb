class ComplianceCheck < ApplicationRecord
  belongs_to :file_resource, optional: true

  validates :asap_id, presence: true, uniqueness: true
  validates :source_url, presence: true

  def self.stats_for_page
    ::ComplianceCheckStats.build
  end
end
