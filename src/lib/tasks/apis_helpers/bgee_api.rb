require 'net/http'

class BGEE_API
  @@BGEE_COLLECTIONS_URL = "https://api.bgee.org/api_15_1/?page=data&action=experiments&data_type=SC_RNA_SEQ&get_results=1&offset=0&limit=1000"
  @@SOURCE = "BGEE"
  @@bgg_datasets_base_url = lambda { |experiment_id| "https://www.bgee.org/api/?page=data&action=raw_data_annots&data_type=SC_RNA_SEQ&get_results=1&offset=0&limit=50&filter_exp_id=#{experiment_id}&filters_for_all=1" }

  def init
    collections_id = get_collections_id
    gather_info collections_id
  end

  def add_to_db
    puts "dataset id #{@data[:dataset_id]}"
    dataset = Dataset.find_or_create_by(dataset_id: @data[:dataset_id])
    dataset.update(@data)
    puts "db updated"
  end

  def changed?(json)
    stringified = JSON.generate(json)
    hash = Digest::SHA256.hexdigest(stringified)
    dataset = Dataset.find_by dataset_id: json[0][:dataset_id]
    if dataset.nil? || (dataset[:dataset_hash] != hash)
      @data[:dataset_hash] = hash
      return true
    else
      return false
    end
  end


  def get_collections_id
    collections_id = []
    http = Net::HTTP
    url = URI.parse(@@BGEE_COLLECTIONS_URL)
    req = http.get(url)

    collections = JSON.parse(req, { symbolize_names: true })
    collections[:data][:results][:SC_RNA_SEQ].each do |collection|
      collections_id << collection[:xRef][:xRefId]
    end
    puts "collections id added #{collections_id}"
    return collections_id
  end

  def gather_info(collections_id)
    collections_id.each do |id|
      puts "gather info of id #{id}"
      http = Net::HTTP
      url = URI.parse(@@bgg_datasets_base_url.call(id))
      req = http.get(url)

        collection = JSON.parse(req, { symbolize_names: true })

        @data = {
          collection_id: nil,
          dataset_id: nil,
          source: nil,
          doi: nil,
          dataset_hash: nil,
          number_of_cells: [],
          organisms: [],
          disease: [],
          assay_info: [],
          processed_data: [],
          link_to_dataset: [],
          link_to_explore_data: [],
          link_to_raw_data: [],
          cell_types: [],
          tissue: [],
          tissue_uberon: [],
          developmental_stage: [],
          developmental_stage_id: [],
          sex: [],
      }

        # checking id there is an exception and if the datasets has changed
        if collection[:data][:exceptionType].nil? && changed?(collection[:data][:results][:SC_RNA_SEQ])

          # Diving in datasets
          collection[:data][:results][:SC_RNA_SEQ].each do |dataset|

            @data[:collection_id] = dataset[:library][:experiment][:xRef][:xRefId]
            @data[:link_to_dataset] = nil
            @data[:source] = @@SOURCE
            @data[:doi] = dataset[:library][:experiment][:dOI]
            @data[:number_of_cells] << nil

            @data[:link_to_raw_data] << dataset[:library][:experiment][:xRef][:xRefURL]

            @data[:dataset_id] = dataset[:library][:id]
            @data[:link_to_explore_data] = nil
            @data[:cell_types] << dataset[:annotation][:rawDataCondition][:cellType][:name]
            @data[:tissue] << dataset[:annotation][:rawDataCondition][:anatEntity][:name]
            @data[:tissue_uberon] << dataset[:annotation][:rawDataCondition][:anatEntity][:id]
            @data[:developmental_stage] << dataset[:annotation][:rawDataCondition][:devStage][:name]
            @data[:developmental_stage_id] << dataset[:annotation][:rawDataCondition][:devStage][:id]
            @data[:sex] << dataset[:annotation][:rawDataCondition][:sex]
            @data[:organisms] << dataset[:annotation][:rawDataCondition][:species][:name]
            @data[:disease] << 'normal' # always normal for Bgee according to discussions
            @data[:assay_info] << dataset[:library][:technology][:protocolName]

            dataset[:library][:experiment][:downloadFiles].each do |source|
              @data[:processed_data] << "#{source[:path]}#{source[:fileName]}"
            end

          end
          add_to_db
        else
          puts 'does not change or Exception'
        end
      end
    end

  end
