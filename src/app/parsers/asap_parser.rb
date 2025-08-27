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
      source: source,
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
      update_sexes(dataset, extract_sexes(data))
      update_developmental_stages(dataset, extract_developmental_stages(data))
      update_diseases(dataset, extract_diseases(data))
      update_tissues(dataset, extract_tissues(data))
      update_technologies(dataset, data[:technology])
      update_file_resources(dataset, extract_files(data))
      update_links(dataset, data.dig(:experiments))

      puts "Imported #{dataset.id}"
    else
      @errors << "Failed to save dataset #{data[:public_key]}: #{dataset.errors.full_messages.join(', ')}"
    end
  end

  def source
    @source ||= Source.find_or_create_by(slug: "asap") do |source|
      source.name = "ASAP"
      source.logo = "asap.svg"
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

  def extract_sexes(data)
    return [] unless data[:sex].present?

    data[:sex].map do |sex_data|
      {
        name: sex_data[:name],
        identifier: sex_data[:identifier]
      }
    end.compact.uniq
  end

  def extract_developmental_stages(data)
    return [] unless data[:developmental_stage].present?

    data[:developmental_stage].map do |stage_data|
      {
        name: stage_data[:name],
        identifier: stage_data[:identifier]
      }
    end.compact.uniq
  end

  def extract_diseases(data)
    return [] unless data[:disease].present?

    data[:disease].map do |disease_data|
      {
        name: disease_data[:name],
        identifier: disease_data[:identifier]
      }
    end.compact.uniq
  end

  def extract_tissues(data)
    return [] unless data[:tissue].present?

    data[:tissue].map do |tissue_data|
      {
        name: tissue_data[:name],
        identifier: tissue_data[:identifier]
      }
    end.compact.uniq
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
                name: cell_type_data[:name],
                ontology_term_id: ontology_term.id
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

      if taxonomy_id.present?
        identifier = "NCBITaxon:#{taxonomy_id}"
        ontology_term = OntologyTerm.find_by(identifier: identifier)

        if ontology_term
          organism_record = Organism
            .where(
              name: organism_name,
              ontology_term_id: ontology_term.id
            )
            .first

          unless organism_record
            organism_record = Organism.create!(
              name: organism_name,
              ontology_term_id: ontology_term.id
            )
          end

          dataset.organisms << organism_record unless dataset.organisms.include?(organism_record)
        else
          ParsingIssue.create!(
            dataset:  dataset,
            resource: Organism.name,
            value:    organism_name,
            external_reference_id: taxonomy_id.to_s,
            message:  "Ontology term with identifier '#{identifier}' not found",
            status:   :pending
          )
        end
      else
        @errors << "Organism without tax_id: #{organism_name}, dataset: #{dataset.source_reference_id}"
      end
    end
  end

  def update_sexes(dataset, sexes_data)
    dataset.sexes.clear

    sexes_data.each do |sex_data|
      next if sex_data[:name].blank?

      sex_name = sex_data[:name].strip.downcase
      ontology_term = nil

      if sex_data[:identifier].present?
        ontology_term = OntologyTerm.find_by(identifier: sex_data[:identifier])

        unless ontology_term
          ParsingIssue.create!(
            dataset: dataset,
            resource: Sex.name,
            value: sex_data[:name],
            external_reference_id: sex_data[:identifier],
            message: "Ontology term with identifier '#{sex_data[:identifier]}' not found",
            status: :pending
          )
        end
      else
        case sex_name
        when 'male'
          ontology_term = OntologyTerm.find_by(identifier: 'PATO:0000384')
        when 'female'
          ontology_term = OntologyTerm.find_by(identifier: 'PATO:0000383')
        end

        if ontology_term.nil? && ['male', 'female'].include?(sex_name)
          ParsingIssue.create!(
            dataset: dataset,
            resource: Sex.name,
            value: sex_data[:name],
            external_reference_id: nil,
            message: "Could not find expected ontology term for sex '#{sex_data[:name]}'",
            status: :pending
          )
        end
      end

      if ontology_term
        sex_record = Sex.find_or_create_by(
          name: sex_data[:name].strip,
          ontology_term_id: ontology_term.id
        )
        dataset.sexes << sex_record unless dataset.sexes.include?(sex_record)
      else
        sex_record = Sex.find_or_create_by(
          name: sex_data[:name].strip,
          ontology_term_id: nil
        )
        dataset.sexes << sex_record unless dataset.sexes.include?(sex_record)

        @errors << "Sex without ontology mapping: #{sex_data[:name]}, dataset: #{dataset.source_reference_id}"
      end
    end
  end

  def update_developmental_stages(dataset, stages_data)
    dataset.developmental_stages.clear

    stages_data.each do |stage_data|
      next if stage_data[:name].blank?

      ontology_term = nil

      if stage_data[:identifier].present?
        ontology_term = OntologyTerm.find_by(identifier: stage_data[:identifier])

        unless ontology_term
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

      if ontology_term
        stage_record = DevelopmentalStage.find_or_create_by(
          name: stage_data[:name].strip,
          ontology_term_id: ontology_term.id
        )
        dataset.developmental_stages << stage_record unless dataset.developmental_stages.include?(stage_record)
      else
        stage_record = DevelopmentalStage.find_or_create_by(
          name: stage_data[:name].strip,
          ontology_term_id: nil
        )
        dataset.developmental_stages << stage_record unless dataset.developmental_stages.include?(stage_record)

        @errors << "Developmental stage without ontology mapping: #{stage_data[:name]}, dataset: #{dataset.source_reference_id}"
        ParsingIssue.create!(
          dataset: dataset,
          resource: DevelopmentalStage.name,
          value: stage_record.name,
          external_reference_id: nil,
          message: "Could not find expected ontology term for developmental stage '#{stage_record.name}'",
          status: :pending
        )
      end
    end
  end

  def update_diseases(dataset, diseases_data)
    dataset.diseases.clear

    diseases_data.each do |disease_data|
      next if disease_data[:name].blank?

      ontology_term = nil

      if disease_data[:identifier].present?
        ontology_term = OntologyTerm.find_by(identifier: disease_data[:identifier])

        unless ontology_term
          ParsingIssue.create!(
            dataset: dataset,
            resource: Disease.name,
            value: disease_data[:name],
            external_reference_id: disease_data[:identifier],
            message: "Ontology term with identifier '#{disease_data[:identifier]}' not found",
            status: :pending
          )
        end
      end

      if ontology_term
        disease_record = Disease.find_or_create_by(
          name: disease_data[:name].strip,
          ontology_term_id: ontology_term.id
        )
        dataset.diseases << disease_record unless dataset.diseases.include?(disease_record)
      else
        disease_record = Disease.find_or_create_by(
          name: disease_data[:name].strip,
          ontology_term_id: nil
        )
        dataset.diseases << disease_record unless dataset.diseases.include?(disease_record)

        @errors << "Disease without ontology mapping: #{disease_data[:name]}, dataset: #{dataset.source_reference_id}"

        ParsingIssue.create!(
          dataset: dataset,
          resource: Disease.name,
          value: disease_record.name,
          external_reference_id: nil,
          message: "Could not find expected ontology term for disease '#{disease_record.name}'",
          status: :pending
        )
      end
    end
  end

  def update_tissues(dataset, tissues_data)
    dataset.tissues.clear

    tissues_data.each do |tissue_data|
      next if tissue_data[:name].blank?

      ontology_term = nil

      if tissue_data[:identifier].present?
        ontology_term = OntologyTerm.find_by(identifier: tissue_data[:identifier])

        unless ontology_term
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

      if ontology_term
        tissue_record = Tissue.find_or_create_by(
          name: tissue_data[:name].strip,
          ontology_term_id: ontology_term.id
        )
        dataset.tissues << tissue_record unless dataset.tissues.include?(tissue_record)
      else
        tissue_record = Tissue.find_or_create_by(
          name: tissue_data[:name].strip,
          ontology_term_id: nil
        )
        dataset.tissues << tissue_record unless dataset.tissues.include?(tissue_record)

        @errors << "Tissue without ontology mapping: #{tissue_data[:name]}, dataset: #{dataset.source_reference_id}"

        ParsingIssue.create!(
          dataset: dataset,
          resource: Tissue.name,
          value: tissue_record.name,
          external_reference_id: nil,
          message: "Could not find expected ontology term for tissue '#{tissue_record.name}'",
          status: :pending
        )
      end
    end
  end

  def update_technologies(dataset, technologies)
    dataset.technologies.clear

    Array(technologies).flatten.each do |technology|
      tech_name, identifier =
        case technology
        when Hash
          [technology[:name], technology[:identifier]]
        else
          [technology, nil]
        end

      next if tech_name.blank?

      # Normalise various capitalisations of 10x/10X
      normalized_tech = tech_name.to_s.gsub(/\b10X\b/i, "10x").strip
      next if normalized_tech.blank?

      technology_record = nil

      if identifier.present?
        ontology_term = OntologyTerm.find_by(identifier: identifier)

        if ontology_term
          technology_record = Technology.find_or_create_by(
            name:             normalized_tech,
            ontology_term_id: ontology_term.id
          )
        else
          ParsingIssue.create!(
            dataset:               dataset,
            resource:              Technology.name,
            value:                 normalized_tech,
            external_reference_id: identifier,
            message:               "Ontology term with identifier '#{identifier}' not found",
            status:                :pending
          )

          technology_record = Technology.find_or_create_by(
            name:             normalized_tech,
            ontology_term_id: nil
          )
        end
      else
        technology_record = Technology.find_or_create_by(
          name:             normalized_tech,
          ontology_term_id: nil
        )
      end

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
