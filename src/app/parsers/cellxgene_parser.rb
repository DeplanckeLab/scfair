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
      source: source,
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

  def source
    @source ||= Source.find_or_create_by(slug: "cxg") do |source|
      source.name = "CELLxGENE"
      source.logo = "cellxgene.svg"
    end
  end

  def update_sexes(dataset, sexes_data)
    dataset.sexes.clear

    sexes_data.each do |sex_hash|
      sex_name = sex_hash.fetch(:label, "")
      next if sex_name.blank? || sex_name.strip.downcase == "unknown"

      ontology_identifier = sex_hash.fetch(:ontology_term_id, "")
      if ontology_identifier.present?
        ontology_term = OntologyTerm.find_by(identifier: ontology_identifier)

        if ontology_term
          sex_record = Sex
            .where(
              "LOWER(name) = LOWER(?) AND ontology_term_id = ?",
              sex_name,
              ontology_term.id
            )
            .first

          unless sex_record
            sex_record = Sex.create!(
              name: sex_name.strip,
              ontology_term: ontology_term
            )
          end

          dataset.sexes << sex_record unless dataset.sexes.include?(sex_record)
          next
        else
          ParsingIssue.create!(
            dataset: dataset,
            resource: Sex.name,
            value: sex_name,
            external_reference_id: ontology_identifier,
            message: "Ontology term with identifier '#{ontology_identifier}' not found",
            status: :pending
          )
        end
      end

      @errors << "Sex without identifier: #{sex_name}, dataset: #{dataset.source_reference_id}" if ontology_identifier.blank?
    end
  end

  def update_cell_types(dataset, cell_types_data)
    dataset.cell_types.clear

    cell_types_data.each do |cell_type_data|
      cell_type_name = cell_type_data.fetch(:label, "")
      next if cell_type_name.blank? || cell_type_name.strip.downcase == "unknown"

      ontology_identifier = cell_type_data.fetch(:ontology_term_id, "")
      if ontology_identifier.present?
        ontology_term = OntologyTerm.find_by(identifier: ontology_identifier)

        if ontology_term
          cell_type_record = CellType
            .where(
              "LOWER(name) = LOWER(?) AND ontology_term_id = ?",
              cell_type_name.strip,
              ontology_term.id
            )
            .first

          unless cell_type_record
            cell_type_record = CellType.create!(
              name: cell_type_name.strip,
              ontology_term_id: ontology_term.id
            )
          end

          dataset.cell_types << cell_type_record unless dataset.cell_types.include?(cell_type_record)
          next
        else
          ParsingIssue.create!(
            dataset: dataset,
            resource: CellType.name,
            value: cell_type_name,
            external_reference_id: ontology_identifier,
            message: "Ontology term with identifier '#{ontology_identifier}' not found",
            status: :pending
          )
        end
      end

      @errors << "Cell type without identifier: #{cell_type_name}, dataset: #{dataset.source_reference_id}" if ontology_identifier.blank?
    end
  end

  def update_tissues(dataset, tissues_data)
    dataset.tissues.clear

    tissues_data.each do |tissue_data|
      tissue_name = tissue_data.fetch(:label, "")
      next if tissue_name.blank? || tissue_name.strip.downcase == "unknown"

      ontology_identifier = tissue_data.fetch(:ontology_term_id, "")
      if ontology_identifier.present?
        ontology_term = OntologyTerm.find_by(identifier: ontology_identifier)

        if ontology_term
          tissue_record = Tissue
            .where(
              "LOWER(name) = LOWER(?) AND ontology_term_id = ?",
              tissue_name.strip,
              ontology_term.id
            )
            .first

          unless tissue_record
            tissue_record = Tissue.create!(
              name: tissue_name.strip,
              ontology_term_id: ontology_term.id
            )
          end

          dataset.tissues << tissue_record unless dataset.tissues.include?(tissue_record)
          next
        else
          ParsingIssue.create!(
            dataset: dataset,
            resource: Tissue.name,
            value: tissue_name,
            external_reference_id: ontology_identifier,
            message: "Ontology term with identifier '#{ontology_identifier}' not found",
            status: :pending
          )
        end
      end

      @errors << "Tissue without identifier: #{tissue_name}, dataset: #{dataset.source_reference_id}" if ontology_identifier.blank?
    end
  end

  def update_developmental_stages(dataset, stages_data)
    dataset.developmental_stages.clear

    stages_data.each do |stage_data|
      stage_name = stage_data.fetch(:label, "")
      next if stage_name.blank? || stage_name.strip.downcase == "unknown"

      ontology_identifier = stage_data.fetch(:ontology_term_id, "")
      if ontology_identifier.present?
        ontology_term = OntologyTerm.find_by(identifier: ontology_identifier)

        if ontology_term
          stage_record = DevelopmentalStage
            .where(
              "LOWER(name) = LOWER(?) AND ontology_term_id = ?",
              stage_name.strip,
              ontology_term.id
            )
            .first

          unless stage_record
            stage_record = DevelopmentalStage.create!(
              name: stage_name.strip,
              ontology_term_id: ontology_term.id
            )
          end

          dataset.developmental_stages << stage_record unless dataset.developmental_stages.include?(stage_record)
          next
        else
          ParsingIssue.create!(
            dataset: dataset,
            resource: DevelopmentalStage.name,
            value: stage_name,
            external_reference_id: ontology_identifier,
            message: "Ontology term with identifier '#{ontology_identifier}' not found",
            status: :pending
          )
        end
      end

      @errors << "Developmental stage without identifier: #{stage_name}, dataset: #{dataset.source_reference_id}" if ontology_identifier.blank?
    end
  end

  def update_organisms(dataset, organisms_data)
    dataset.organisms.clear

    organisms_data.each do |org_hash|
      ontology_identifier = org_hash.fetch(:ontology_term_id)
      ontology_term = OntologyTerm.find_by(identifier: ontology_identifier)
      log_missing_ontology("organism", ontology_identifier, dataset.id) unless ontology_term

      organism_name = org_hash.fetch(:label, "")
      taxonomy_id = ontology_identifier.split(":").last
      next unless organism_name.present?

      begin
        organism = Organism.search_by_data(organism_name, taxonomy_id)
        organism.update!(ontology_term: ontology_term)
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

  def update_diseases(dataset, diseases_data)
    dataset.diseases.clear

    diseases_data.each do |disease_data|
      disease_name = disease_data.fetch(:label, "")
      next if disease_name.blank?

      raw_identifier = disease_data.fetch(:ontology_term_id, "")
      if raw_identifier.present?
        identifiers = raw_identifier.to_s.split(/\s*\|\|\s*/).map(&:strip).reject(&:blank?).uniq

        identifiers.each do |ontology_identifier|
          ontology_term = OntologyTerm.find_by(identifier: ontology_identifier)

          if ontology_term
            record_name = ontology_term.name.presence || disease_name.strip
            disease_record = Disease
              .where(
                "LOWER(name) = LOWER(?) AND ontology_term_id = ?",
                record_name,
                ontology_term.id
              )
              .first

            unless disease_record
              disease_record = Disease.create!(
                name: record_name,
                ontology_term_id: ontology_term.id
              )
            end

            dataset.diseases << disease_record unless dataset.diseases.include?(disease_record)
          else
            ParsingIssue.create!(
              dataset: dataset,
              resource: Disease.name,
              value: disease_name,
              external_reference_id: ontology_identifier,
              message: "Ontology term with identifier '#{ontology_identifier}' not found",
              status: :pending
            )
          end
        end

        next
      end

      @errors << "Disease without identifier: #{disease_name}, dataset: #{dataset.source_reference_id}" if raw_identifier.blank?
    end
  end

  def update_technologies(dataset, assay_data)
    return unless assay_data

    dataset.technologies.clear

    assay_data.each do |assay_data|
      technology_name = assay_data.fetch(:label, "").gsub(/\b10X\b/, '10x')
      next if technology_name.blank?

      ontology_identifier = assay_data.fetch(:ontology_term_id, "")
      if ontology_identifier.present?
        ontology_term = OntologyTerm.find_by(identifier: ontology_identifier)

        if ontology_term
          technology_record = Technology
            .where(
              "LOWER(name) = LOWER(?) AND ontology_term_id = ?",
              technology_name.strip,
              ontology_term.id
            )
            .first

          unless technology_record
            technology_record = Technology.create!(
              name: technology_name.strip,
              ontology_term_id: ontology_term.id
            )
          end

          dataset.technologies << technology_record unless dataset.technologies.include?(technology_record)
          next
        else
          ParsingIssue.create!(
            dataset: dataset,
            resource: Technology.name,
            value: technology_name,
            external_reference_id: ontology_identifier,
            message: "Ontology term with identifier '#{ontology_identifier}' not found",
            status: :pending
          )
        end
      end

      @errors << "Technology without identifier: #{technology_name}, dataset: #{dataset.source_reference_id}" if ontology_identifier.blank?
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
