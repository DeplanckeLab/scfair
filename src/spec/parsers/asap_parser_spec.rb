require "rails_helper"

RSpec.describe AsapParser do
  let(:parser) { described_class.new }
  
  let(:dataset_data) do
    {
      public_key: "test123",
      doi: "10.1234/test",
      nber_cols: 1000,
      organism: "human",
      technology: "RNA-seq",
      key: "test123",
      experiments: [
        { url: "http://example.com/acc1.cgi" },
        { url: "http://example.com/acc2.cgi" }
      ],
      annotation_groups: [
        {
          annotations: [
            {
              cell_ontology_terms: [
                { name: "T cell" },
                { name: "B cell" }
              ]
            }
          ]
        }
      ]
    }
  end

  describe "#perform" do
    before do
      allow(HTTParty).to receive(:get).with(described_class::BASE_URL)
        .and_return(double(body: [dataset_data].to_json))
    end

    it "processes collections successfully" do
      expect(parser.perform).to be true
      expect(parser.errors).to be_empty
    end

    context "when there's an error fetching collections" do
      before do
        allow(HTTParty).to receive(:get)
          .and_raise(StandardError.new("API Error"))
      end

      it "handles the error gracefully" do
        expect(parser.perform).to be false
        expect(parser.errors).to include("Error fetching collections: API Error")
      end
    end
  end

  describe "#process_dataset" do
    it "creates a new dataset with associated records" do
      expect {
        parser.send(:process_dataset, dataset_data)
      }.to change(Dataset, :count).by(1)

      dataset = Dataset.last
      expect(dataset.source_name).to eq("ASAP")
      expect(dataset.doi).to eq("10.1234/test")
      expect(dataset.cell_count).to eq(1000)
      
      expect(dataset.cell_types.pluck(:name)).to contain_exactly("T cell", "B cell")
      expect(dataset.organisms.pluck(:name)).to contain_exactly("human")
      expect(dataset.technologies.pluck(:name)).to contain_exactly("RNA-seq")
      expect(dataset.file_resources.count).to eq(3) # 2 raw files + 1 processed
    end

    it "updates existing dataset when parser_hash changes" do
      parser.send(:process_dataset, dataset_data)
      initial_dataset = Dataset.last
      initial_hash = initial_dataset.parser_hash

      modified_data = dataset_data.deep_dup
      modified_data[:technology] = "ATAC-seq"
      
      parser.send(:process_dataset, modified_data)
      
      updated_dataset = Dataset.last
      expect(updated_dataset.id).to eq(initial_dataset.id)
      expect(updated_dataset.parser_hash).not_to eq(initial_hash)
      expect(updated_dataset.technologies.pluck(:name)).to contain_exactly("ATAC-seq")
    end

    it "skips processing when parser_hash hasn't changed" do
      parser.send(:process_dataset, dataset_data)
      initial_dataset = Dataset.last
      
      expect {
        parser.send(:process_dataset, dataset_data)
      }.not_to change(Dataset, :count)
      
      expect(Dataset.last.parser_hash).to eq(initial_dataset.parser_hash)
    end
  end
end 