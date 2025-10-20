# frozen_string_literal: true

module Search
  class DatasetIndexer
    class << self
      def index(dataset)
        doc = DatasetDocumentBuilder.new(dataset).as_json
        ElasticsearchClient.index(index: "datasets", id: dataset.id, body: doc, refresh: "wait_for")
      end

      def delete(dataset_id)
        ElasticsearchClient.delete(index: "datasets", id: dataset_id)
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        true
      end

      def bulk_index(relation, batch_size: 250, ancestor_cache: nil)
        total = relation.is_a?(ActiveRecord::Relation) ? relation.count : relation.size
        processed = 0
        
        relation.find_in_batches(batch_size: batch_size) do |batch|
          body = []
          batch.each do |dataset|
            body << { index: { _index: "datasets", _id: dataset.id } }
            body << DatasetDocumentBuilder.new(dataset, ancestor_cache: ancestor_cache).as_json
          end

          with_retries do
            ElasticsearchClient.bulk(body: body, refresh: false)
          end

          processed += batch.size
          Rails.logger.info("Bulk indexed #{processed}/#{total} datasets") if processed % 500 == 0
        end
        ElasticsearchClient.indices.refresh(index: "datasets")
      end

      private

      def with_retries(max: 3)
        attempts = 0
        begin
          attempts += 1
          return yield
        rescue StandardError
          raise if attempts >= max
          sleep(2 ** attempts)
          retry
        end
      end
    end
  end
end
