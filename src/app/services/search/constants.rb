# frozen_string_literal: true

module Search
  module Constants
    # Elasticsearch index names
    DATASETS_INDEX = "datasets"
    ONTOLOGY_INDEX = "ontology_terms"

    # Aggregation limits
    MAX_AGGREGATION_SIZE = 10_000

    # Pagination defaults
    DEFAULT_PAGE = 1
    DEFAULT_PER_PAGE = 12
    DEFAULT_FACET_LIMIT = 30

    # Empty result structures
    EMPTY_AGGREGATION = {}.freeze
    EMPTY_RESULTS = [].freeze
  end
end
