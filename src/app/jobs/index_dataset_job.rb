# frozen_string_literal: true

class IndexDatasetJob < ApplicationJob
  queue_as :default

  def perform(dataset_id)
    dataset = Dataset.find_by(id: dataset_id)
    return unless dataset

    Search::DatasetIndexer.index(dataset)
  end
end
