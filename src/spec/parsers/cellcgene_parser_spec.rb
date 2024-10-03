require "rails_helper"

RSpec.describe CellxgeneParser do
  let(:parser) { described_class.new }

  describe "#perform" do
    context "when API fetch is successful" do
      before do
        allow(parser).to receive(:fetch_collections).and_return([{
          collection_id: "test-collection-id",
          collection_url: "https://example.com",
          doi: "10.1234/doi"
        }])

        allow(parser).to receive(:fetch_collection).with("test-collection-id").and_return({
          datasets: [{
            dataset_id: "test-dataset-id",
            explorer_url: "https://explorer.com",
            cell_count: 100,
            sex: [{ label: "Female", ontology_term_id: "test-ontology-id" }],
            tissue: [{ label: "Lung", ontology_term_id: "tissue-ontology-id" }],
            assets: [{ url: "https://example.com/file.h5ad", filetype: "H5AD" }]
          }]
        })
      end

      it "processes collections and datasets" do
        expect { parser.perform }.to change { Dataset.count }.by(1)
        dataset = Dataset.find_by(source_reference_id: "test-dataset-id")
        expect(dataset.cell_count).to eq(100)
        expect(dataset.sexes.pluck(:name)).to include("Female")
        expect(dataset.tissues.pluck(:name)).to include("Lung")
        expect(dataset.file_resources.count).to eq(1)
        expect(dataset.file_resources.first.filetype).to eq("h5ad")
      end

      it "does not add duplicates" do
        parser.perform
        expect { parser.perform }.not_to change { Dataset.count }
      end
    end

    context "when there is an error fetching collections" do
      before do
        allow(HTTParty).to receive(:get).and_raise(StandardError, "API Error")
      end

      it "logs the error and returns false" do
        result = parser.perform
        
        expect(result).to eq(false)
        expect(parser.errors).to include(a_string_matching(/Error fetching collections: API Error/))
      end
    end

    context "when dataset save fails" do
      before do
        allow(parser).to receive(:fetch_collections).and_return([{
          collection_id: "test-collection-id",
          collection_url: "https://example.com",
          doi: "10.1234/doi"
        }])

        allow(parser).to receive(:fetch_collection).with("test-collection-id").and_return({
          datasets: [{
            dataset_id: "test-dataset-id",
            explorer_url: "https://explorer.com",
            cell_count: 100,
            sex: [{ label: "Female", ontology_term_id: "test-ontology-id" }],
            tissue: [{ label: "Lung", ontology_term_id: "tissue-ontology-id" }],
            assets: [{ url: "https://example.com/file.h5ad", filetype: "H5AD" }]
          }]
        })

        allow_any_instance_of(Dataset).to receive(:save).and_return(false)
        allow_any_instance_of(Dataset).to receive_message_chain(:errors, :full_messages).and_return(["Invalid data"])
      end

      it "logs dataset save errors" do
        expect { parser.perform }.not_to change { Dataset.count }
        expect(parser.errors).to include("Failed to save dataset : Invalid data")
      end
    end
  end

  describe "Private Methods" do
    let(:collection_data) do
      {
        collection_id: "test-collection-id",
        collection_url: "https://example.com",
        doi: "10.1234/doi"
      }
    end

    describe "#process_collection" do
      it "creates a Collection struct with the correct data" do
        collection = parser.send(:process_collection, collection_data)
        expect(collection.id).to eq("test-collection-id")
        expect(collection.url).to eq("https://example.com")
        expect(collection.doi).to eq("10.1234/doi")
      end
    end

    describe "#update_sexes" do
      let(:dataset) { create(:dataset) }

      it "adds new sex associations to the dataset" do
        sexes_data = [{ label: "Female", ontology_term_id: "test-ontology-id" }]
        expect { parser.send(:update_sexes, dataset, sexes_data) }.to change { dataset.sexes.count }.by(1)
        expect(dataset.sexes.first.name).to eq("Female")
      end
    end

    describe "#update_file_resources" do
      let(:dataset) { create(:dataset) }

      it "creates new file resources" do
        assets_data = [{ url: "https://example.com/file.h5ad", filetype: "H5AD" }]
        expect { parser.send(:update_file_resources, dataset, assets_data) }.to change { dataset.file_resources.count }.by(1)
        expect(dataset.file_resources.first.url).to eq("https://example.com/file.h5ad")
        expect(dataset.file_resources.first.filetype).to eq("h5ad")
      end
    end
  end
end
