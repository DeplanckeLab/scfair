class AsapParser
  BASE_URL = "https://asap.epfl.ch/projects.json"

  attr_reader :errors

  def initialize
    @errors = []
  end

  def perform
    fetch_collections.each do |collection_data|
      process_dataset(collection_data)
    end

    @errors.empty?
  end

  private

  def fetch_collections
    response = HTTParty.get(BASE_URL)
    JSON.parse(response.body, symbolize_names: true)
  rescue => e
    @errors << "Error fetching collections: #{e.message}"
    []
  end

  def process_dataset(data)
    parser_hash = Digest::SHA256.hexdigest(data.to_s)
    dataset = Dataset.find_or_initialize_by(source_reference_id: data[:public_key])
    
    return if dataset.parser_hash == parser_hash

    dataset_data = {
      collection_id: "ASAP000000",
      source_name: "ASAP",
      source_url: "https://asap.epfl.ch/projects/#{data[:public_key]}",
      explorer_url: "",
      doi: data[:doi],
      cell_count: data[:nber_cols],
      parser_hash: parser_hash
    }

    dataset.assign_attributes(dataset_data)

    if dataset.save
      update_cell_types(dataset, extract_cell_types(data))
      update_organisms(dataset, [data[:organism]].compact)
      update_technologies(dataset, [data[:technology]].compact)
      update_file_resources(dataset, extract_files(data))
      update_dataset_links(dataset, data.dig(:experiments))
      
      puts "Imported #{dataset.id}"
    else
      @errors << "Failed to save dataset #{data[:public_key]}: #{dataset.errors.full_messages.join(', ')}"
    end
  end

  def extract_cell_types(data)
    data[:annotation_groups].flat_map do |group|
      group[:annotations].flat_map do |annotation|
        annotation[:cell_ontology_terms].map { |term| term[:name] }
      end
    end.compact.uniq
  end

  def extract_files(data)
    files = []
    
    files << {
      url: "https://asap.epfl.ch/projects/#{data[:key]}/get_file?filename=parsing/output.h5ad",
      filetype: "h5ad"
    }
    
    files
  end

  def update_cell_types(dataset, cell_types)
    dataset.cell_types.clear
    cell_types.each do |cell_type|
      next if cell_type.blank?
      
      cell_type_record = CellType.find_or_create_by(name: cell_type)
      dataset.cell_types << cell_type_record unless dataset.cell_types.include?(cell_type_record)
    end
  end

  def update_organisms(dataset, organisms)
    dataset.organisms.clear
    organisms.each do |organism|
      next if organism.blank?
      
      organism_record = Organism.find_or_create_by(name: organism)
      dataset.organisms << organism_record unless dataset.organisms.include?(organism_record)
    end
  end

  def update_technologies(dataset, technologies)
    dataset.technologies.clear
    technologies.each do |technology|
      next if technology.blank?
      
      technology_record = Technology.find_or_create_by(protocol_name: technology)
      dataset.technologies << technology_record unless dataset.technologies.include?(technology_record)
    end
  end

  def update_file_resources(dataset, files)
    files.each do |file|
      next if file[:url].blank?
      
      filetype = file[:filetype].to_s.downcase
      next unless filetype.in?(FileResource::VALID_FILETYPES)
      
      dataset.file_resources.find_or_create_by(
        url: file[:url],
        filetype: filetype
      )
    end
  end

  def update_dataset_links(dataset, experiments)
    dataset.dataset_links.clear    
    experiments.each do |experiment|
      dataset.dataset_links.find_or_create_by(url: experiment[:url])
    end
  end
end 
