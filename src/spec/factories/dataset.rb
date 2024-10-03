FactoryBot.define do
  factory :dataset do
    source_reference_id { "test-dataset-id" }
    cell_count { 100 }
    source_name { "CELLxGENE" }
    source_url { "https://example.com" }
    explorer_url { "https://explorer.example.com" }
    collection_id { "test-collection-id" }
    doi { "10.1234/example.doi" }
    parser_hash { "test_parser_hash" }
  end
end
