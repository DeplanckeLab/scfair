class DatasetValidator
  class ValidationError < StandardError; end

  attr_reader :errors, :processed_count, :total_count

  BATCH_SIZE = 100

  def initialize(source_slug = nil)
    @source_slug = source_slug
    @errors = []
    @processed_count = 0
    @total_count = 0
  end

  def validate!
    return puts "No valid source name provided" unless source

    @total_count = Dataset.processing.where(source: source).count

    if @total_count.zero?
      @errors << "No datasets found for source: #{source.name}"
      return false
    end

    puts "Starting validation of #{@total_count} datasets..."

    Solr::IndexingControl.without_indexing do
      Dataset.processing.includes(:organisms, :cell_types).where(source: source).find_each(batch_size: BATCH_SIZE) do |dataset|
        validate_dataset(dataset)
        @processed_count += 1

        if @processed_count % BATCH_SIZE == 0
          puts "Processed #{@processed_count}/#{@total_count} datasets..."
        end
      end
    end

    puts "Validation completed: #{@processed_count} datasets processed, #{@errors.count} errors found."

    puts "Updating ontology coverage for #{source.name}..."
    OntologyCoverageService.update_for_source(source)
    puts "Ontology coverage updated!"

    @errors.empty?
  end

  private

  def source
    @source ||= Source.find_by(slug: @source_slug)
  end

  def validate_dataset(dataset)
    begin
      validate_ontology_coverage(dataset)
      dataset.completed!

    rescue ValidationError => e
      dataset.failed!
      @errors << "Dataset #{dataset.id}: #{e.message}"
    rescue => e
      @errors << "Dataset #{dataset.id}: Unexpected error - #{e.message}"
      puts "WARNING: Unexpected error for dataset #{dataset.id}: #{e.message}"
    end
  end

  def validate_ontology_coverage(dataset)
    has_cell_type_ontology = dataset.cell_types.any? { |ct| ct.ontology_term_id.present? }
    has_organism_ontology = dataset.organisms.any? { |org| org.ontology_term_id.present? }

    if !has_cell_type_ontology || !has_organism_ontology
      validation_errors = []

      validation_errors << {
        annotation: CellType.name,
        message: "No cell types are linked to ontological terms",
      } unless has_cell_type_ontology

      validation_errors << {
        annotation: Organism.name,
        message: "No organisms are linked to ontological terms",
      } unless has_organism_ontology

      add_validation_errors(dataset, validation_errors)
      raise ValidationError, "Dataset lacks required ontology coverage"
    end
  end

  def add_validation_errors(dataset, validation_errors)
    notes = dataset.notes || {}
    notes[:validation_errors] ||= []

    validation_errors.each do |error|
      notes[:validation_errors] << {
        annotation: error[:annotation],
        message: error[:message],
        timestamp: Time.current.utc.to_s
      }
    end

    dataset.update!(notes: notes)
  end
end
