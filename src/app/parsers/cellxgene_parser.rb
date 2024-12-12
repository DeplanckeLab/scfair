Collection = Struct.new(:id, :url, :doi, :links) do
  def initialize(id:, url:, doi:, links:)
    super(id, url, doi, links)
  end
end

class CellxgeneParser
  BASE_URL = "https://api.cellxgene.cziscience.com/curation/v1/collections/".freeze

  attr_reader :errors, :warnings

  def initialize
    @errors = []
    @warnings = []
  end

  def perform
    fetch_collections.each do |collection_data|
      collection = process_collection(collection_data)
      
      datasets = fetch_collection(collection.id).fetch(:datasets, [])
      datasets.each do |dataset_data|
        process_dataset(dataset_data, collection)
      end
    end

    @errors.empty?
  end

  private

  def log_missing_ontology(type, identifier, dataset_id)
    @warnings << "Missing ontology term for #{type}: #{identifier} in dataset #{dataset_id}"
  end

  def fetch_collections
    response = HTTParty.get(BASE_URL)
    JSON.parse(response.body, symbolize_names: true)
  rescue => e
    @errors << "Error fetching collections: #{e.message}"
    []
  end

  def fetch_collection(id)
    return unless id

    response = HTTParty.get("#{BASE_URL}#{id}")
    JSON.parse(response.body, symbolize_names: true)
  rescue => e
    @errors << "Error fetching collection data for #{id}: #{e.message}"
    {}
  end

  def process_collection(data)
    Collection.new(
      id: data.fetch(:collection_id),
      url: data.fetch(:collection_url, ""),
      doi: data.fetch(:doi, ""),
      links: data.fetch(:links, [])
    )
  end

  def process_dataset(data, collection)
    parser_hash = Digest::SHA256.hexdigest(data.to_s)

    dataset = Dataset.find_or_initialize_by(source_reference_id: data[:dataset_id])

    return if dataset.parser_hash == parser_hash

    dataset.assign_attributes(
      collection_id: collection.id,
      source_name: "CELLxGENE",
      source_url: collection.url,
      explorer_url: data.fetch(:explorer_url, ""),
      doi: collection.doi,
      cell_count: data.fetch(:cell_count, 0),
      parser_hash: parser_hash
    )

    if dataset.save
      update_sexes(dataset, data.fetch(:sex, []))
      update_cell_types(dataset, data.fetch(:cell_type, []))
      update_tissues(dataset, data.fetch(:tissue, []))
      update_developmental_stages(dataset, data.fetch(:development_stage, []))
      update_organisms(dataset, data.fetch(:organism, []))
      update_diseases(dataset, data.fetch(:disease, []))
      update_technologies(dataset, data.fetch(:assay, []))
      update_file_resources(dataset, data.fetch(:assets))
      update_links(dataset, collection.links)

      puts "Imported #{dataset.id}"
    else
      @errors << "Failed to save dataset #{dataset.id}: #{dataset.errors.full_messages.join(", ")}"
    end
  end

  def update_sexes(dataset, sexes_data)
    dataset.sexes.clear
    sexes_data.each do |sex_hash|
      ontology_identifier = sex_hash.fetch(:ontology_term_id)
      ontology_term = OntologyTerm.find_by(identifier: ontology_identifier)
      log_missing_ontology("sex", ontology_identifier, dataset.id) unless ontology_term

      sex = Sex.find_or_create_by(name: sex_hash.fetch(:label, "")) do |s|
        s.ontology_term = ontology_term
      end

      dataset.sexes << sex unless dataset.sexes.include?(sex)
    end
  end

  def update_cell_types(dataset, cell_types_data)
    dataset.cell_types.clear
    cell_types_data.each do |ct_hash|
      ontology_identifier = ct_hash.fetch(:ontology_term_id)
      ontology_term = OntologyTerm.find_by(identifier: ontology_identifier)
      log_missing_ontology("cell type", ontology_identifier, dataset.id) unless ontology_term

      cell_type = CellType.find_or_create_by(name: ct_hash.fetch(:label, "")) do |ct|
        ct.ontology_term = ontology_term
      end

      dataset.cell_types << cell_type unless dataset.cell_types.include?(cell_type)
    end
  end

  def update_tissues(dataset, tissues_data)
    dataset.tissues.clear
    tissues_data.each do |tissue_hash|
      ontology_identifier = tissue_hash.fetch(:ontology_term_id)
      ontology_term = OntologyTerm.find_by(identifier: ontology_identifier)
      log_missing_ontology("tissue", ontology_identifier, dataset.id) unless ontology_term

      tissue = Tissue.find_or_create_by(name: tissue_hash.fetch(:label, "")) do |t|
        t.ontology_term = ontology_term
      end
      
      dataset.tissues << tissue unless dataset.tissues.include?(tissue)
    end
  end

  def update_developmental_stages(dataset, stages_data)
    dataset.developmental_stages.clear
    stages_data.each do |stage_hash|
      ontology_identifier = stage_hash.fetch(:ontology_term_id)
      ontology_term = OntologyTerm.find_by(identifier: ontology_identifier)
      log_missing_ontology("developmental stage", ontology_identifier, dataset.id) unless ontology_term

      stage = DevelopmentalStage.find_or_create_by(name: stage_hash.fetch(:label, "")) do |ds|
        ds.ontology_term = ontology_term
      end
      
      dataset.developmental_stages << stage unless dataset.developmental_stages.include?(stage)
    end
  end

  def update_organisms(dataset, organisms_data)
    dataset.organisms.clear
    organisms_data.each do |org_hash|
      ontology_identifier = org_hash.fetch(:ontology_term_id)
      ontology_term = OntologyTerm.find_by(identifier: ontology_identifier)
      log_missing_ontology("organism", ontology_identifier, dataset.id) unless ontology_term

      organism = Organism.find_or_create_by(name: org_hash.fetch(:label, "")) do |o|
        o.ontology_term = ontology_term
      end

      dataset.organisms << organism unless dataset.organisms.include?(organism)
    end
  end

  def update_diseases(dataset, diseases_data)
    dataset.diseases.clear
    diseases_data.each do |disease_hash|
      ontology_identifier = disease_hash.fetch(:ontology_term_id)
      ontology_term = OntologyTerm.find_by(identifier: ontology_identifier)
      log_missing_ontology("disease", ontology_identifier, dataset.id) unless ontology_term

      disease = Disease.find_or_create_by(name: disease_hash.fetch(:label, "")) do |d|
        d.ontology_term = ontology_term
      end

      dataset.diseases << disease unless dataset.diseases.include?(disease)
    end
  end

  def update_technologies(dataset, assay_data)
    return unless assay_data
    
    dataset.technologies.clear
    assay_data.each do |assay_hash|
      ontology_identifier = assay_hash.fetch(:ontology_term_id)
      ontology_term = OntologyTerm.find_by(identifier: ontology_identifier)
      log_missing_ontology("technology", ontology_identifier, dataset.id) unless ontology_term

      technology = Technology.find_or_create_by(protocol_name: assay_hash.fetch(:label, "")) do |t|
        t.ontology_term = ontology_term
      end

      dataset.technologies << technology unless dataset.technologies.include?(technology)
    end
  end

  def update_file_resources(dataset, assets_data)
    assets_data.each do |asset_hash|
      filetype = asset_hash.fetch(:filetype, "").to_s.downcase
      next unless filetype.in?(FileResource::VALID_FILETYPES)

      dataset.file_resources.find_or_create_by(
        url: asset_hash.fetch(:url, ""),
        filetype: filetype
      )
    end
  end

  def update_links(dataset, links_data)
    dataset.links.clear
    links_data.each do |link_hash|
      dataset.links.create(url: link_hash.fetch(:link_url, ""))
    end
  end
end
