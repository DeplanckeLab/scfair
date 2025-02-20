class SinglecellParser
  BASE_URL_STUDIES     = "https://singlecell.broadinstitute.org/single_cell/api/v1/site/studies".freeze
  BASE_URL_ANNOTATIONS = "https://singlecell.broadinstitute.org/single_cell/api/v1/studies/".freeze
  BASE_URL_EXPLORE     = "https://singlecell.broadinstitute.org/single_cell/study/".freeze

  attr_reader :errors

  def initialize
    @errors = []
  end

  def perform
    studies = fetch_studies
    studies.each do |study_data|
      process_dataset(study_data)
    end

    @errors.empty?
  end

  private

  def fetch_studies
    response = HTTParty.get(BASE_URL_STUDIES, verify: false)
    JSON.parse(response.body, symbolize_names: true)
  rescue => e
    @errors << "Error fetching studies: #{e.message}"
    []
  end

  def fetch_annotations(study_id)
    url = "#{BASE_URL_ANNOTATIONS}#{study_id}/annotations"
    response = HTTParty.get(url, verify: false)
    JSON.parse(response.body, symbolize_names: true)
  rescue => e
    @errors << "Error fetching annotations for study #{study_id}: #{e.message}"
    {}
  end

  def process_dataset(study_data)
    study_id = study_data[:accession]
    return if study_id.blank?

    annotations_data = fetch_annotations(study_id)

    explore_url = "#{BASE_URL_EXPLORE}#{study_id}"
    parser_hash = Digest::SHA256.hexdigest(study_data.to_s + annotations_data.to_s)

    dataset = Dataset.find_or_initialize_by(source_reference_id: study_id)
    return if dataset.parser_hash == parser_hash

    cell_count = study_data[:cell_count]
    return if cell_count.blank? || !cell_count.to_s.match?(/\A[0-9]+\z/) || cell_count.to_i.zero?

    dataset_data = {
      collection_id: study_id,
      source_name:   "SINGLECELL",
      source_url:    "#{BASE_URL_ANNOTATIONS}#{study_id}/annotations",
      explorer_url:  explore_url,
      doi:           nil,
      cell_count:    cell_count,
      parser_hash:   parser_hash
    }

    dataset.assign_attributes(dataset_data)

    if dataset.save
      update_cell_types(dataset, annotations_data)
      update_organisms(dataset, annotations_data)
      update_sexes(dataset, annotations_data)
      update_diseases(dataset, annotations_data)
      update_technologies(dataset, annotations_data)

      update_links(dataset, study_id)
      
      puts "Imported #{dataset.id}"
    else
      @errors << "Failed to save dataset #{study_id}: #{dataset.errors.full_messages.join(', ')}"
    end
  end

  # Extracts the organism information from the annotations.
  # Expected input:
  #   {
  #     name: "species", values: ["NCBITaxon_9606"]
  #   },
  #   {
  #     name: "species__ontology_label", values: ["Homo sapiens"]
  #   }
  def update_organisms(dataset, annotations_data)
    return unless annotations_data.is_a?(Array) && annotations_data.any?

    species_annotation = annotations_data.find { |a| a[:name] == "species" }
    label_annotation   = annotations_data.find { |a| a[:name] == "species__ontology_label" }
    return unless species_annotation && label_annotation

    tax_entry = species_annotation[:values].first.to_s.strip
    tax_id = tax_entry.split(/[_:]+/).last rescue nil
    organism_name = label_annotation[:values].first.to_s.strip

    return if organism_name.blank? || tax_id.blank?

    begin
      organism = Organism.search_by_data(organism_name, tax_id)
      dataset.organisms << organism unless dataset.organisms.include?(organism)
    rescue ActiveRecord::RecordNotFound, MultipleMatchesError => e
      ParsingIssue.create!(
        dataset: dataset,
        resource: Organism.name,
        value: organism_name,
        external_reference_id: tax_id.to_s,
        message: e.message,
        status: :pending
      )
    end
  end

  def update_cell_types(dataset, annotations_data)
    return unless annotations_data.is_a?(Array) && annotations_data.any?

    cell_annotation = annotations_data.find { |a| a[:name] == "cell_type__ontology_label" }
    return unless cell_annotation

    cell_types = cell_annotation[:values].uniq.compact
    dataset.cell_types.clear
    cell_types.each do |cell_type|
      next if cell_type.blank?
      cell_type_record = CellType.where("name ILIKE ?", cell_type).first_or_create(name: cell_type)
      dataset.cell_types << cell_type_record unless dataset.cell_types.include?(cell_type_record)
    end
  end

  def update_sexes(dataset, annotations_data)
    return unless annotations_data.is_a?(Array) && annotations_data.any?

    sex_annotation = annotations_data.find { |a| a[:name] == "sex" }
    return unless sex_annotation

    sexes = sex_annotation[:values].uniq.compact
    dataset.sexes.clear
    sexes.each do |sex|
      next if sex.blank?
      sex_record = Sex.where("name ILIKE ?", sex).first_or_create(name: sex)
      dataset.sexes << sex_record unless dataset.sexes.include?(sex_record)
    end
  end

  def update_diseases(dataset, annotations_data)
    return unless annotations_data.is_a?(Array) && annotations_data.any?

    disease_annotation = annotations_data.find { |a| a[:name] == "disease__ontology_label" }
    return unless disease_annotation

    diseases = disease_annotation[:values].uniq.compact
    dataset.diseases.clear
    diseases.each do |disease|
      next if disease.blank?
      disease_record = Disease.where("name ILIKE ?", disease).first_or_create(name: disease)
      dataset.diseases << disease_record unless dataset.diseases.include?(disease_record)
    end
  end

  def update_technologies(dataset, annotations_data)
    return unless annotations_data.is_a?(Array) && annotations_data.any?

    tech_annotation = annotations_data.find { |a| a[:name] == "library_preparation_protocol__ontology_label" }
    return unless tech_annotation

    technologies = tech_annotation[:values].uniq.compact
    dataset.technologies.clear
    technologies.each do |tech|
      next if tech.blank?
      tech_record = Technology.where("name ILIKE ?", tech).first_or_create(name: tech)
      dataset.technologies << tech_record unless dataset.technologies.include?(tech_record)
    end
  end

  def update_links(dataset, study_id)
    external_resources = fetch_external_resources(study_id)
    return unless external_resources.is_a?(Array) && external_resources.any?

    dataset.links.clear
    external_resources.each do |resource|
      resource_url = resource[:url]
      next if resource_url.blank?
      dataset.links.where("url ILIKE ?", resource_url).first_or_create(url: resource_url, name: resource[:description])
    end
  end

  def fetch_external_resources(study_id)
    url = "#{BASE_URL_ANNOTATIONS}#{study_id}/external_resources"
    response = HTTParty.get(url, verify: false)
    JSON.parse(response.body, symbolize_names: true)
  rescue => e
    @errors << "Error fetching external resources for study #{study_id}: #{e.message}"
    []
  end
end 