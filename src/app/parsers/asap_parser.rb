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

    OntologyCoverageService.update_for_source("ASAP")

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
      source_url: "https://asap.epfl.ch/projects.json",
      explorer_url: "https://asap.epfl.ch/projects/#{data[:public_key]}",
      doi: data[:doi],
      cell_count: data[:nber_cols],
      parser_hash: parser_hash
    }

    dataset.assign_attributes(dataset_data)

    if dataset.save
      update_cell_types(dataset, extract_cell_types(data))
      update_organisms(dataset, [{ label: data[:organism], tax_id: data[:tax_id] }].compact)
      update_technologies(dataset, [data[:technology]].compact)
      update_file_resources(dataset, extract_files(data))
      update_links(dataset, data.dig(:experiments))
      
      puts "Imported #{dataset.id}"
    else
      @errors << "Failed to save dataset #{data[:public_key]}: #{dataset.errors.full_messages.join(', ')}"
    end
  end

  def extract_cell_types(data)
    data[:annotation_groups].flat_map do |group|
      group[:annotations].flat_map do |annotation|
        annotation[:cell_ontology_terms].map do |term|
          {
            name: term[:name],
            identifier: term[:identifier]
          }
        end
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

  def update_cell_types(dataset, cell_types_data)
    dataset.cell_types.clear

    cell_types_data.each do |cell_type_data|
      next if cell_type_data[:name].blank?
      
      if cell_type_data[:identifier].present?
        ontology_term = OntologyTerm.find_by(identifier: cell_type_data[:identifier])
        
        if ontology_term
            cell_type_record = CellType
              .where(
                "LOWER(name) = LOWER(?) AND ontology_term_id = ?", 
                cell_type_data[:name], 
                ontology_term.id
              )
              .first
              
            unless cell_type_record
              cell_type_record = CellType.create!(
                name: cell_type_data[:name].strip,
                ontology_term_id: ontology_term.id
              )
            end
            
            dataset.cell_types << cell_type_record unless dataset.cell_types.include?(cell_type_record)
            next
        else
          ParsingIssue.create!(
            dataset: dataset,
            resource: CellType.name,
            value: cell_type_data[:name],
            external_reference_id: cell_type_data[:identifier],
            message: "Ontology term with identifier '#{cell_type_data[:identifier]}' not found",
            status: :pending
          )
        end
      end

      @errors << "Cell type without identifier: #{cell_type_data[:name]}, dataset: #{dataset.source_reference_id}" if cell_type_data[:identifier].blank?
    end
  end

  def update_organisms(dataset, organisms_data)
    dataset.organisms.clear
    organisms_data.each do |organism_data|
      organism_name = organism_data[:label]
      taxonomy_id = organism_data[:tax_id]
      next if organism_name.blank?
      
      begin
        organism = Organism.search_by_data(organism_name, taxonomy_id)
        dataset.organisms << organism unless dataset.organisms.include?(organism)
      rescue ActiveRecord::RecordNotFound, MultipleMatchesError => e
        ParsingIssue.create!(
          dataset:  dataset,
          resource: Organism.name,
          value:    organism_name,
          external_reference_id: taxonomy_id.to_s,
          message:  e.message,
          status:   :pending
        )
        next
      end
    end
  end

  def update_technologies(dataset, technologies)
    dataset.technologies.clear
    technologies.each do |technology|
      next if technology.blank?

      normalized_tech = technology.gsub(/\b10X\b/, '10x')
      next if normalized_tech.blank?
      
      technology_record = Technology.find_or_create_by(name: normalized_tech)
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

  def update_links(dataset, experiments)
    dataset.links.clear    
    experiments.each do |experiment|
      dataset.links.find_or_create_by(url: experiment[:url])
    end
  end
end 
