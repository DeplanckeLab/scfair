# frozen_string_literal: true

module Search
  DATASETS_INDEX = "datasets"
  ONTOLOGY_INDEX = "ontology_terms"
  MAX_AGGREGATION_SIZE = 10_000
  DEFAULT_PAGE = 1
  DEFAULT_PER_PAGE = 12
  DEFAULT_FACET_LIMIT = 30

  class << self
    def client
      @client ||= Elasticsearch::Client.new(
        url: ENV.fetch("ELASTICSEARCH_URL", "http://localhost:9200"),
        log: Rails.env.development?
      )
    end
  end
end
