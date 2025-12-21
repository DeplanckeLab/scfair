# frozen_string_literal: true

require "elasticsearch"
require "oj"

ELASTICSEARCH_URL = ENV.fetch("ELASTICSEARCH_URL", "http://localhost:9200")

Rails.application.configure do
  config.x.search = ActiveSupport::OrderedOptions.new
  config.x.search.elasticsearch_url = ELASTICSEARCH_URL
end

ElasticsearchClient = Elasticsearch::Client.new(
  url: ELASTICSEARCH_URL,
  transport_options: { request: { timeout: 120, open_timeout: 5 } }
)
