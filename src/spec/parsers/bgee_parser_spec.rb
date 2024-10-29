require "rails_helper"

RSpec.describe BgeeParser do
  let(:parser) { described_class.new }
  
  let(:dataset_data) do
    {
      library: {
        id: "LIB1",
        experiment: {
          xRef: { xRefId: "EXP1", xRefURL: "http://example.com" },
          dOI: "doi:123",
          downloadFiles: [
            { path: "http://example.com/", fileName: "file1.h5ad", filetype: "H5AD" },
            { path: "http://example.com/", fileName: "file2.csv", filetype: "CSV" }
          ],
        },
        technology: { protocolName: "RNA-Seq" }
      },
      annotation: {
        rawDataCondition: {
          sex: "male",
          species: { name: "human" },
          cellType: { name: "neuron" },
          anatEntity: { name: "brain" },
          devStage: { name: "adult" }
        }
      }
    }
  end

  let(:collection_response) do
    {
      data: {
        results: {
          SC_RNA_SEQ: [dataset_data]
        }
      }
    }
  end

  let(:valid_dataset_attributes) do
    {
      source_reference_id: "test",
      source_name: "BGEE",
      collection_id: "test_collection",
      source_url: "",
      explorer_url: "",
      cell_count: 0,
      parser_hash: "test_hash"
    }
  end

  describe "#perform" do
    before do
      allow(HTTParty).to receive(:get).with(described_class::BASE_URL)
        .and_return(double(body: { data: { results: { SC_RNA_SEQ: [{ xRef: { xRefId: "EXP1" } }] } } }.to_json))
      
      allow(HTTParty).to receive(:get).with(described_class::DATASET_URL.call("EXP1"))
        .and_return(double(body: collection_response.to_json))
    end

    it "processes collections successfully" do
      expect(parser.perform).to be true
      expect(parser.errors).to be_empty
    end

    context "when there's an error fetching collections" do
      before do
        allow(HTTParty).to receive(:get).with(described_class::BASE_URL)
          .and_raise(StandardError.new("API Error"))
      end

      it "handles the error gracefully" do
        expect(parser.perform).to be false
        expect(parser.errors).to include("Error fetching collections: API Error")
      end
    end

    context "when there's an error processing a collection" do
      before do
        allow(HTTParty).to receive(:get).with(described_class::DATASET_URL.call("EXP1"))
          .and_raise(StandardError.new("Processing Error"))
      end

      it "handles the error gracefully" do
        expect(parser.perform).to be false
        expect(parser.errors).to include("Error processing collection EXP1: Processing Error")
      end
    end
  end

  describe "#process_datasets" do
    it "creates a new dataset with associated records" do
      expect {
        parser.send(:process_datasets, [dataset_data])
      }.to change(Dataset, :count).by(1)

      dataset = Dataset.last
      expect(dataset.source_name).to eq("BGEE")
      expect(dataset.doi).to eq("doi:123")
      
      expect(dataset.sexes.pluck(:name)).to contain_exactly("male")
      expect(dataset.organisms.pluck(:name)).to contain_exactly("human")
      expect(dataset.cell_types.pluck(:name)).to contain_exactly("neuron")
      expect(dataset.tissues.pluck(:name)).to contain_exactly("brain")
      expect(dataset.developmental_stages.pluck(:name)).to contain_exactly("adult")
      expect(dataset.diseases.pluck(:name)).to contain_exactly("normal")
      expect(dataset.technologies.pluck(:protocol_name)).to contain_exactly("RNA-Seq")
    end

    it "updates existing dataset when parser_hash changes" do
      parser.send(:process_datasets, [dataset_data])
      initial_dataset = Dataset.last
      initial_hash = initial_dataset.parser_hash

      modified_data = dataset_data.deep_dup
      modified_data[:annotation][:rawDataCondition][:sex] = "female"
      
      parser.send(:process_datasets, [modified_data])
      
      updated_dataset = Dataset.last
      expect(updated_dataset.id).to eq(initial_dataset.id)
      expect(updated_dataset.parser_hash).not_to eq(initial_hash)
      expect(updated_dataset.sexes.pluck(:name)).to contain_exactly("female")
    end

    it "skips processing when parser_hash hasn't changed" do
      parser.send(:process_datasets, [dataset_data])
      initial_dataset = Dataset.last
      
      expect {
        parser.send(:process_datasets, [dataset_data])
      }.not_to change(Dataset, :count)
      
      expect(Dataset.last.parser_hash).to eq(initial_dataset.parser_hash)
    end
  end

  describe "association updates" do
    let(:dataset) { Dataset.create!(valid_dataset_attributes) }

    it "updates sexes" do
      parser.send(:update_sexes, dataset, ["male", "female"])
      expect(dataset.sexes.pluck(:name)).to contain_exactly("male", "female")
    end

    it "updates organisms" do
      parser.send(:update_organisms, dataset, ["human", "mouse"])
      expect(dataset.organisms.pluck(:name)).to contain_exactly("human", "mouse")
    end

    it "updates cell types" do
      parser.send(:update_cell_types, dataset, ["neuron", "astrocyte"])
      expect(dataset.cell_types.pluck(:name)).to contain_exactly("neuron", "astrocyte")
    end

    it "updates tissues" do
      parser.send(:update_tissues, dataset, ["brain", "heart"])
      expect(dataset.tissues.pluck(:name)).to contain_exactly("brain", "heart")
    end

    it "updates developmental stages" do
      parser.send(:update_developmental_stages, dataset, ["adult", "embryo"])
      expect(dataset.developmental_stages.pluck(:name)).to contain_exactly("adult", "embryo")
    end

    it "updates diseases" do
      parser.send(:update_diseases, dataset, ["normal", "cancer"])
      expect(dataset.diseases.pluck(:name)).to contain_exactly("normal", "cancer")
    end

    it "updates technologies" do
      parser.send(:update_technologies, dataset, ["RNA-Seq", "ATAC-Seq"])
      expect(dataset.technologies.pluck(:protocol_name)).to contain_exactly("RNA-Seq", "ATAC-Seq")
    end
  end
end