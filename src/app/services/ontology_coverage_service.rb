class OntologyCoverageService
  def self.update_for_source(source_name)
    new(source_name).update_coverage
  end

  def initialize(source_name)
    @source_name = source_name
  end

  def update_coverage
    Dataset::ASSOCIATION_METHODS.each do |model_class, association_method|
      category_name = model_class.name
      stats = calculate_category_stats(model_class)
      ontology_coverage = OntologyCoverage.find_or_initialize_by(
        source: source_name,
        category: category_name
      )
  
      ontology_coverage.assign_attributes(stats)
      ontology_coverage.save!
    end
  end

  private

  attr_reader :source_name

  def calculate_category_stats(model_class)
    association_method = Dataset::ASSOCIATION_METHODS[model_class]
    return default_stats unless association_method

    source_datasets = Dataset.where(source_name: source_name)
    
    return default_stats if source_datasets.empty?

    category_items = model_class.joins(:datasets).where(datasets: { source_name: source_name }).distinct
    records = category_items.count

    return default_stats if records == 0

    relationships = model_class.joins(:datasets)
                              .where(datasets: { source_name: source_name })
                              .count

    mapped_count = category_items.where.not(ontology_term_id: nil).count
    
    parsing_issues_count = ParsingIssue.joins(:dataset)
                                      .where(datasets: { source_name: source_name })
                                      .where(resource: model_class.name)
                                      .count

    total_attempts = mapped_count + parsing_issues_count
    ontology_coverage = total_attempts > 0 ? (mapped_count.to_f / total_attempts * 100).round : 0

    {
      records: records,
      relationships: relationships,
      ontology_coverage: ontology_coverage
    }
  end

  def default_stats
    {
      records: 0,
      relationships: 0,
      ontology_coverage: 0
    }
  end
end
