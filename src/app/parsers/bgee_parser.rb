class BgeeParser
  BASE_URL = "https://api.bgee.org/api_15_1/?page=data&action=experiments&data_type=SC_RNA_SEQ&get_results=1&offset=0&limit=1000"
  DATASET_URL = lambda { |experiment_id| "https://www.bgee.org/api/?page=data&action=raw_data_annots&data_type=SC_RNA_SEQ&get_results=1&offset=0&limit=50&filter_exp_id=#{experiment_id}&filters_for_all=1" }

  attr_reader :errors

  def initialize
    @errors = []
  end

  def perform
    fetch_collection_ids.each do |id|
      process_collection(id)
    end

    @errors.empty?
  end

  private

  def fetch_collection_ids
    response = HTTParty.get(BASE_URL)
    collections = JSON.parse(response.body, symbolize_names: true)
    collections.dig(:data, :results, :SC_RNA_SEQ)&.map { |collection| collection.dig(:xRef, :xRefId) } || []
  rescue => e
    @errors << "Error fetching collections: #{e.message}"
    []
  end

  def process_collection(id)
    return unless id

    response = HTTParty.get(DATASET_URL.call(id))
    collection = JSON.parse(response.body, symbolize_names: true)

    if collection.dig(:data, :exceptionType).nil? && collection.dig(:data, :results, :SC_RNA_SEQ)
      process_datasets(collection.dig(:data, :results, :SC_RNA_SEQ))
    else
      puts "No changes or exception for collection #{id}"
    end
  rescue => e
    @errors << "Error processing collection #{id}: #{e.message}"
  end

  def process_datasets(datasets)
    collection_data = {
      source_reference_id: datasets.first.dig(:library, :experiment, :xRef, :xRefId),
      collection_id: datasets.first.dig(:library, :experiment, :xRef, :xRefId),
      source_name: "BGEE",
      source_url: "",
      explorer_url: "",
      doi: datasets.first.dig(:library, :experiment, :dOI),
      cell_count: 0,
      parser_hash: Digest::SHA256.hexdigest(datasets.to_s)
    }

    dataset = Dataset.find_or_initialize_by(source_reference_id: collection_data[:source_reference_id])
    
    return if dataset.parser_hash == collection_data[:parser_hash]
    
    dataset.assign_attributes(collection_data)

    if dataset.save
      puts "Importing #{dataset.id}"
      
      update_sexes(dataset, datasets.map { |d| d.dig(:annotation, :rawDataCondition, :sex) }.compact.uniq)
      update_organisms(dataset, datasets.map { |d| d.dig(:annotation, :rawDataCondition, :species, :name) }.compact.uniq)
      update_cell_types(dataset, datasets.map { |d| d.dig(:annotation, :rawDataCondition, :cellType, :name) }.compact.uniq)
      update_tissues(dataset, datasets.map { |d| d.dig(:annotation, :rawDataCondition, :anatEntity, :name) }.compact.uniq)
      update_developmental_stages(dataset, datasets.map { |d| d.dig(:annotation, :rawDataCondition, :devStage, :name) }.compact.uniq)
      update_diseases(dataset, ["normal"])
      update_technologies(dataset, datasets.map { |d| d.dig(:library, :technology, :protocolName) }.compact.uniq)
      update_links(dataset, datasets.map { |d| d.dig(:library, :experiment, :xRef, :xRefURL) }.compact.uniq)

      all_files = datasets.flat_map { |d| d.dig(:library, :experiment, :downloadFiles) }.compact
      update_file_resources(dataset, all_files)

      puts "Imported #{dataset.id}"
    else
      @errors << "Failed to save dataset #{collection_data[:source_reference_id]}: #{dataset.errors.full_messages.join(", ")}"
    end
  end

  def update_file_resources(dataset, assets_data)
    return if assets_data.blank?

    assets_data.each do |asset|
      next if asset.nil?

      filetype = File.extname(asset[:fileName].to_s).delete(".").downcase
      next unless filetype.in?(FileResource::VALID_FILETYPES)

      dataset.file_resources.find_or_create_by(
        url: asset[:path] + asset[:fileName],
        filetype: filetype
      )
    end
  end

  def update_sexes(dataset, sexes_data)
    dataset.sexes.clear
    sexes_data.each do |sex|
      next if sex.blank?

      sex_record = Sex.find_or_create_by(name: sex)
      dataset.sexes << sex_record unless dataset.sexes.include?(sex_record)
    end
  end

  def update_organisms(dataset, organisms_data)
    dataset.organisms.clear
    organisms_data.each do |organism_name|
      next if organism_name.blank?

      begin
        organism = Organism.search_by_name(organism_name)

        if organism.nil?
          organism = Organism.search_by_short_name(organism_name)
          if organism.nil?
            ParsingIssue.create!(
              dataset:  dataset,
              resource: Organism.name,
              value:    organism_name,
              message:  "No organism found",
              status:   :pending
            )
            next
          end
        end

        dataset.organisms << organism unless dataset.organisms.include?(organism)
      rescue MultipleMatchesError => e
        ParsingIssue.create!(
          dataset:  dataset,
          resource: Organism.name,
          value:    organism_name,
          message:  e.message,
          status:   :pending
        )
        next
      end
    end
  end

  def update_cell_types(dataset, cell_types_data)
    dataset.cell_types.clear
    cell_types_data.each do |cell_type|
      next if cell_type.blank?

      cell_type_record = CellType.find_or_create_by(name: cell_type)
      dataset.cell_types << cell_type_record unless dataset.cell_types.include?(cell_type_record)
    end
  end

  def update_tissues(dataset, tissues_data)
    dataset.tissues.clear
    tissues_data.each do |tissue|
      next if tissue.blank?

      tissue_record = Tissue.find_or_create_by(name: tissue)
      dataset.tissues << tissue_record unless dataset.tissues.include?(tissue_record)
    end
  end

  def update_developmental_stages(dataset, stages_data)
    dataset.developmental_stages.clear
    stages_data.each do |stage|
      next if stage.blank?

      stage_record = DevelopmentalStage.find_or_create_by(name: stage)
      dataset.developmental_stages << stage_record unless dataset.developmental_stages.include?(stage_record)
    end
  end

  def update_diseases(dataset, diseases_data)
    dataset.diseases.clear
    diseases_data.each do |disease|
      next if disease.blank?

      disease_record = Disease.find_or_create_by(name: disease)
      dataset.diseases << disease_record unless dataset.diseases.include?(disease_record)
    end
  end

  def update_technologies(dataset, technologies_data)
    dataset.technologies.clear
    technologies_data.each do |technology|
      next if technology.blank?

      technology_record = Technology.find_or_create_by(name: technology)
      dataset.technologies << technology_record unless dataset.technologies.include?(technology_record)
    end
  end

  def update_links(dataset, links)
    dataset.links.clear

    links.each do |url|
      next unless url.present?
      
      dataset.links.find_or_create_by(url: url)
    rescue => e
      @errors << "Error creating dataset link for URL #{url}: #{e.message}"
    end
  end
end
