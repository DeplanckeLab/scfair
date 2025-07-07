class OntologyCoverageService
  class << self
    def update_for_source(source)
      new(source).update_coverage
    end
  end

  def initialize(source)
    @source = source
  end

  def update_coverage
    Dataset::ASSOCIATION_METHODS.each do |model_class, association_method|
      category_name = model_class.name
      stats = calculate_category_stats(model_class)
      ontology_coverage = OntologyCoverage.find_or_initialize_by(
        source: source,
        category: category_name
      )
  
      ontology_coverage.assign_attributes(stats)
      ontology_coverage.save!
    end
  end

  private

  attr_reader :source

  def calculate_category_stats(model_class)
    records = records_for(model_class)
    {
      records_count: records.count,
      relationships_count: relationships_count_for(model_class),
      records_with_ontology_count: records.where.not(ontology_term_id: nil).count,
      records_missing_ontology_count: records.where(ontology_term_id: nil).count,
      parsing_issues_count: parsing_issues_count_for(model_class),
    }
  end

  def relationships_count_for(model_class)
    association_method = Dataset::ASSOCIATION_METHODS[model_class]
    Dataset.joins(association_method).where(datasets: { source: source }).count
  end

  def records_for(model_class)
    model_class.joins(:datasets).where(datasets: { source: source }).distinct
  end

  def parsing_issues_count_for(model_class)
    ParsingIssue.joins(:dataset).where(datasets: { source: source }).where(resource: model_class.name).count
  end
end
