class Source < ApplicationRecord
  has_many :datasets, dependent: :destroy

  has_many :ontology_coverage, dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true, uniqueness: true

  def total_datasets_count
    completed_datasets_count + failed_datasets_count
  end

  def completion_rate
    return 0 if total_datasets_count == 0
    (completed_datasets_count.to_f / total_datasets_count * 100).round(2)
  end
end
