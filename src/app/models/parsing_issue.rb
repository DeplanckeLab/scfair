class ParsingIssue < ApplicationRecord
    belongs_to :dataset
    enum :status, { pending: 0, processing: 1, resolved: 2 }, default: :pending
  end
