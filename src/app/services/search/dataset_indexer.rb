# frozen_string_literal: true

module Search
  class DatasetIndexer
    class << self
      include Search::Concerns::Retryable

      def index(dataset)
        doc = DatasetDocumentBuilder.new(dataset).as_json
        ElasticsearchClient.index(index: Constants::DATASETS_INDEX, id: dataset.id, body: doc, refresh: "wait_for")
      end

      def delete(dataset_id)
        ElasticsearchClient.delete(index: Constants::DATASETS_INDEX, id: dataset_id)
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        true
      end

      def bulk_index(relation, batch_size: 250, ancestor_cache: nil)
        total = relation.is_a?(ActiveRecord::Relation) ? relation.count : relation.size
        processed = 0

        relation.find_in_batches(batch_size: batch_size) do |batch|
          body = []
          batch.each do |dataset|
            body << { index: { _index: Constants::DATASETS_INDEX, _id: dataset.id } }
            body << DatasetDocumentBuilder.new(dataset, ancestor_cache: ancestor_cache).as_json
          end

          with_retries(base_delay: 2.0) do
            ElasticsearchClient.bulk(body: body, refresh: false)
          end

          processed += batch.size
          Rails.logger.info("Bulk indexed #{processed}/#{total} datasets") if processed % 500 == 0
        end

        ElasticsearchClient.indices.refresh(index: Constants::DATASETS_INDEX)
      end
    end
  end
end
