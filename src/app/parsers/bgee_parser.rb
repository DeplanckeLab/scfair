class BgeeParser
  BASE_URL = "https://api.bgee.org/api_15_1/?page=data&action=experiments&data_type=SC_RNA_SEQ&get_results=1&offset=0&limit=1000"
  DATASET_URL = lambda { |experiment_id| "https://www.bgee.org/api/?page=data&exp_id=#{experiment_id}" }

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
    data = JSON.parse(response.body, symbolize_names: true)

    if data[:status] == "SUCCESS" && data[:data].present?
      process_experiment_data(data[:data], id)
    end
  rescue => e
    @errors << "Error processing collection #{id}: #{e.message}"
  end

  def process_experiment_data(experiment_data, experiment_id)
    experiment = experiment_data[:experiment]
    return unless experiment

    assays = experiment_data[:assays] || []

    collection_data = {
      source_reference_id: experiment_id,
      collection_id: experiment_id,
      source: source,
      source_url: DATASET_URL.call(experiment_id),
      explorer_url: "https://www.bgee.org/experiment/#{experiment_id}",
      doi: experiment[:dOI],
      cell_count: experiment[:numberOfAnnotatedCells],
      parser_hash: Digest::SHA256.hexdigest(experiment_data.to_s)
    }

    dataset = Dataset.find_or_initialize_by(source_reference_id: collection_data[:source_reference_id])
    return if dataset.parser_hash == collection_data[:parser_hash]

    dataset.assign_attributes(collection_data)

    if dataset.save
      cell_types_data = extract_cell_types(assays)
      tissues_data = extract_tissues(assays)
      dev_stages_data = extract_developmental_stages(assays)
      sexes_data = extract_sexes(assays)
      organisms_data = extract_organisms(assays)
      technologies_data = extract_technologies(assays)

      download_files = experiment[:downloadFiles] || []
      xref_url = experiment[:xRef]&.dig(:xRefURL)
      links = [xref_url].compact.uniq

      update_sexes(dataset, sexes_data)
      update_organisms(dataset, organisms_data)
      update_cell_types(dataset, cell_types_data)
      update_tissues(dataset, tissues_data)
      update_developmental_stages(dataset, dev_stages_data)
      update_diseases(dataset)
      update_technologies(dataset, technologies_data)
      update_links(dataset, links)
      update_file_resources(dataset, download_files)

      puts "Imported #{dataset.id}"
    else
      @errors << "Failed to save dataset #{collection_data[:source_reference_id]}: #{dataset.errors.full_messages.join(", ")}"
    end
  rescue => e
    @errors << "Error processing experiment data for #{experiment_id}: #{e.message}"
  end

  def source
    @source ||= Source.find_or_create_by(slug: "bgee") do |source|
      source.name = "Bgee"
      source.logo = "bgee.svg"
    end
  end

  def extract_cell_types(assays)
    result = []
    assays.each do |assay|
      cell_type = assay.dig(:annotation, :rawDataCondition, :cellType)
      next unless cell_type.is_a?(Hash) && cell_type[:name].present? && cell_type[:id].present?
      result << { name: cell_type[:name], identifier: cell_type[:id] }
    end
    result.uniq { |ct| [ct[:name], ct[:identifier]] }
  end

  def extract_tissues(assays)
    result = []
    assays.each do |assay|
      anat_entity = assay.dig(:annotation, :rawDataCondition, :anatEntity)
      next unless anat_entity.is_a?(Hash) && anat_entity[:name].present? && anat_entity[:id].present?
      result << { name: anat_entity[:name], identifier: anat_entity[:id] }
    end
    result.uniq { |t| [t[:name], t[:identifier]] }
  end

  def extract_developmental_stages(assays)
    result = []
    assays.each do |assay|
      dev_stage = assay.dig(:annotation, :rawDataCondition, :devStage)
      next unless dev_stage.is_a?(Hash) && dev_stage[:name].present? && dev_stage[:id].present?
      result << { name: dev_stage[:name], identifier: dev_stage[:id] }
    end
    result.uniq { |ds| [ds[:name], ds[:identifier]] }
  end

  def extract_sexes(assays)
    assays.map { |assay| assay.dig(:annotation, :rawDataCondition, :sex) }
      .compact
      .select(&:present?)
      .uniq
  end

  def extract_organisms(assays)
    result = []
    assays.each do |assay|
      species = assay.dig(:annotation, :rawDataCondition, :species)
      next unless species.is_a?(Hash) && species[:name].present? && species[:id].present?
      result << { name: species[:name], id: species[:id] }
    end
    result.uniq { |o| o[:id] }
  end

  def extract_technologies(assays)
    assays.map do |assay|
      tech = assay.dig(:library, :technology)
      next unless tech.is_a?(Hash)
      tech[:protocolName]
    end.compact.select(&:present?).uniq
  end

  def update_file_resources(dataset, assets_data)
    return if assets_data.blank?

    assets_data.each do |asset|
      next if asset.nil?

      file_name = asset[:fileName].to_s
      filetype = extract_filetype(asset, file_name)
      next unless filetype.in?(FileResource::VALID_FILETYPES)

      resource = dataset.file_resources.find_or_initialize_by(
        url: build_file_url(asset[:path], file_name),
        filetype: filetype
      )
      resource.title = asset[:title].presence || file_name.presence
      resource.save!
    end
  end

  def extract_filetype(asset, file_name)
    explicit_type = asset[:filetype].presence || asset[:fileType].presence
    normalized_explicit_type = explicit_type.to_s.downcase
    return normalized_explicit_type if normalized_explicit_type.in?(FileResource::VALID_FILETYPES)

    return "tsv.gz" if file_name.downcase.end_with?(".tsv.gz")

    File.extname(file_name).delete(".").downcase
  end

  def build_file_url(path, file_name)
    base_path = path.to_s
    safe_base_path = base_path.end_with?("/") ? base_path : "#{base_path}/"
    encoded_file_name = ERB::Util.url_encode(file_name.to_s).gsub("%2F", "/")

    "#{safe_base_path}#{encoded_file_name}"
  end

  def update_sexes(dataset, sexes_data)
    dataset.sexes.clear
    sexes_data.each do |sex|
      next if sex.blank? || sex.strip.downcase == "na"

      identifier = case sex
        when "male"
          "PATO:0000384"
        when "female"
          "PATO:0000383"
        when "mixed"
          "PATO:0001338"
        else
          nil
      end

      next if identifier.blank?

      ontology_term = OntologyTerm.find_by(identifier: identifier)

      if ontology_term
        sex_record = Sex
          .where(ontology_term_id: ontology_term.id)
          .first_or_create!(name: ontology_term.name.presence || sex)

        dataset.sexes << sex_record unless dataset.sexes.include?(sex_record)
        next
      else
        ParsingIssue.create!(
          dataset: dataset,
          resource: Sex.name,
          value: sex,
          external_reference_id: identifier,
          message: "Ontology term with identifier '#{identifier}' not found",
          status: :pending
        )
      end
    end
  end

  def update_organisms(dataset, organisms_data)
    dataset.organisms.clear
    organisms_data.each do |org_data|
      name = org_data[:name]
      next if name.blank?

      taxonomy_id = org_data[:id]
      identifier = taxonomy_id.present? ? "NCBITaxon:#{taxonomy_id}" : nil

      if identifier.present?
        ontology_term = OntologyTerm.find_by(identifier: identifier)

        if ontology_term
          organism_record = Organism
            .where(ontology_term_id: ontology_term.id)
            .first_or_create!(name: ontology_term.name.presence || name)

          dataset.organisms << organism_record unless dataset.organisms.include?(organism_record)
          next
        else
          ParsingIssue.create!(
            dataset: dataset,
            resource: Organism.name,
            value: name,
            external_reference_id: identifier,
            message: "Ontology term with identifier '#{identifier}' not found",
            status: :pending
          )
        end
      end

      @errors << "Organism without identifier: #{name}, dataset: #{dataset.source_reference_id}" if identifier.blank?
    end
  end

  def update_cell_types(dataset, cell_types_data)
    dataset.cell_types.clear

    cell_types_data.each do |cell_type_data|
      next if cell_type_data[:name].blank?

      if cell_type_data[:identifier].present?
        unless CellType.valid_ontology?(cell_type_data[:identifier])
          ParsingIssue.create!(
            dataset: dataset,
            resource: CellType.name,
            value: cell_type_data[:name],
            external_reference_id: cell_type_data[:identifier],
            message: "Invalid ontology prefix '#{CellType.extract_ontology_prefix(cell_type_data[:identifier])}'. Expected one of: #{CellType::ALLOWED_ONTOLOGIES.join(', ')}",
            status: :pending
          )
          next
        end

        # For FBbt terms, validate it's actually a cell type (not an anatomical structure)
        unless CellType.valid_cell_type_term?(cell_type_data[:identifier])
          ParsingIssue.create!(
            dataset: dataset,
            resource: CellType.name,
            value: cell_type_data[:name],
            external_reference_id: cell_type_data[:identifier],
            message: "FBbt term '#{cell_type_data[:identifier]}' is not a cell type (not a descendant of FBbt:00007002 'cell')",
            status: :pending
          )
          next
        end

        ontology_term = OntologyTerm.find_by(identifier: cell_type_data[:identifier])

        if ontology_term
          cell_type_record = CellType
            .where(ontology_term_id: ontology_term.id)
            .first_or_create!(name: ontology_term.name.presence || cell_type_data[:name])

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

  def update_tissues(dataset, tissues_data)
    dataset.tissues.clear

    tissues_data.each do |tissue_data|
      next if tissue_data[:name].blank?

      if tissue_data[:identifier].present?
        unless Tissue.valid_ontology?(tissue_data[:identifier])
          ParsingIssue.create!(
            dataset: dataset,
            resource: Tissue.name,
            value: tissue_data[:name],
            external_reference_id: tissue_data[:identifier],
            message: "Invalid ontology prefix '#{Tissue.extract_ontology_prefix(tissue_data[:identifier])}'. Expected one of: #{Tissue::ALLOWED_ONTOLOGIES.join(', ')}",
            status: :pending
          )
          next
        end

        ontology_term = OntologyTerm.find_by(identifier: tissue_data[:identifier])

        if ontology_term
          tissue_record = Tissue
            .where(ontology_term_id: ontology_term.id)
            .first_or_create!(name: ontology_term.name.presence || tissue_data[:name])

          dataset.tissues << tissue_record unless dataset.tissues.include?(tissue_record)
          next
        else
          ParsingIssue.create!(
            dataset: dataset,
            resource: Tissue.name,
            value: tissue_data[:name],
            external_reference_id: tissue_data[:identifier],
            message: "Ontology term with identifier '#{tissue_data[:identifier]}' not found",
            status: :pending
          )
        end
      end

      @errors << "Tissue without identifier: #{tissue_data[:name]}, dataset: #{dataset.source_reference_id}" if tissue_data[:identifier].blank?
    end
  end

  def update_developmental_stages(dataset, stages_data)
    dataset.developmental_stages.clear

    stages_data.each do |stage_data|
      next if stage_data[:name].blank?

      cleaned_stage_name = stage_data[:name].gsub(/\s*\([^)]*\)\s*/, '').strip

      if stage_data[:identifier].present?
        unless DevelopmentalStage.valid_ontology?(stage_data[:identifier])
          ParsingIssue.create!(
            dataset: dataset,
            resource: DevelopmentalStage.name,
            value: stage_data[:name],
            external_reference_id: stage_data[:identifier],
            message: "Invalid ontology prefix '#{DevelopmentalStage.extract_ontology_prefix(stage_data[:identifier])}'. Expected one of: #{DevelopmentalStage::ALLOWED_ONTOLOGIES.join(', ')}",
            status: :pending
          )
          next
        end

        ontology_term = OntologyTerm.find_by(identifier: stage_data[:identifier])

        if ontology_term
          stage_record = DevelopmentalStage
            .where(ontology_term_id: ontology_term.id)
            .first_or_create!(name: ontology_term.name.presence || cleaned_stage_name)

          dataset.developmental_stages << stage_record unless dataset.developmental_stages.include?(stage_record)
          next
        else
          ParsingIssue.create!(
            dataset: dataset,
            resource: DevelopmentalStage.name,
            value: stage_data[:name],
            external_reference_id: stage_data[:identifier],
            message: "Ontology term with identifier '#{stage_data[:identifier]}' not found",
            status: :pending
          )
        end
      end

      @errors << "Developmental stage without identifier: #{cleaned_stage_name}, dataset: #{dataset.source_reference_id}" if stage_data[:identifier].blank?
    end
  end

  def update_diseases(dataset)
    dataset.diseases.clear

    ontology_term = OntologyTerm.find_by(identifier: "PATO:0000461")
    disease = "normal"

    if ontology_term
      disease_record = Disease
        .where(ontology_term_id: ontology_term.id)
        .first_or_create!(name: ontology_term.name.presence || disease)

      dataset.diseases << disease_record unless dataset.diseases.include?(disease_record)
    else
      ParsingIssue.create!(
        dataset: dataset,
        resource: Disease.name,
        value: disease,
        external_reference_id: "PATO:0000461",
        message: "Ontology term with identifier 'PATO:0000461' not found",
        status: :pending
      )
    end
  end

  def update_technologies(dataset, technologies_data)
    dataset.technologies.clear
    technologies_data.each do |technology|
      next if technology.blank?

      normalized_tech = technology.to_s.gsub(/\b10X\b/i, '10x').strip
      next if normalized_tech.blank?

      technology_record = Technology.find_by(name: normalized_tech)

      unless technology_record
        technology_record = Technology.create!(name: normalized_tech)

        ParsingIssue.create!(
          dataset: dataset,
          resource: Technology.name,
          value: normalized_tech,
          external_reference_id: nil,
          message: "Technology without identifier",
          status: :pending
        )
      end

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
