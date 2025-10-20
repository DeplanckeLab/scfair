class Dataset < ApplicationRecord
  ASSOCIATION_METHODS = {
    Organism => :organisms,
    CellType => :cell_types,
    Tissue => :tissues,
    DevelopmentalStage => :developmental_stages,
    Disease => :diseases,
    Sex => :sexes,
    Technology => :technologies,
    SuspensionType => :suspension_types
  }.freeze

  CATEGORIES = ASSOCIATION_METHODS.keys.freeze

  enum :status, { processing: "processing", completed: "completed", failed: "failed" }

  has_and_belongs_to_many :sexes
  has_and_belongs_to_many :cell_types
  has_and_belongs_to_many :tissues
  has_and_belongs_to_many :developmental_stages
  has_and_belongs_to_many :organisms
  has_and_belongs_to_many :diseases
  has_and_belongs_to_many :technologies
  has_and_belongs_to_many :suspension_types

  has_many :links, class_name: "DatasetLink"
  has_many :file_resources
  has_many :parsing_issues

  belongs_to :study, primary_key: :doi, foreign_key: :doi, optional: true
  belongs_to :source, dependent: :destroy

  after_update :update_source_counters, if: :saved_change_to_status?
  after_destroy :decrement_source_counters

  after_commit on: [:create, :update] do
    IndexDatasetJob.perform_later(id)
  end

  after_destroy do
    Search::DatasetIndexer.delete(id)
  end

  def associated_category_items_for(category)
    association_method = ASSOCIATION_METHODS[category]
    raise ArgumentError, "Invalid category: #{category}. Must be one of: #{CATEGORIES.join(', ')}" unless association_method
    send(association_method)
  end

  private

  def update_source_counters
    return unless source.present?

    old_status, new_status = saved_change_to_status

    case old_status
    when "completed"
      source.decrement!(:completed_datasets_count)
    when "failed"
      source.decrement!(:failed_datasets_count)
    end

    case new_status
    when "completed"
      source.increment!(:completed_datasets_count)
    when "failed"
      source.increment!(:failed_datasets_count)
    end
  end

  def decrement_source_counters
    return unless source.present?

    if completed?
      source.decrement!(:completed_datasets_count)
    elsif failed?
      source.decrement!(:failed_datasets_count)
    end
  end
end
