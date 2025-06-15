class Dataset < ApplicationRecord
  SOURCES = { cxg: "CELLxGENE", bgee: "Bgee", asap: "ASAP", scp: "Single Cell Portal" }.freeze
  ASSOCIATION_METHODS = {
    Organism => :organisms,
    CellType => :cell_types,
    Tissue => :tissues,
    DevelopmentalStage => :developmental_stages,
    Disease => :diseases,
    Sex => :sexes,
    Technology => :technologies
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

  has_many :links, class_name: "DatasetLink"
  has_many :file_resources
  has_many :parsing_issues

  belongs_to :study, primary_key: :doi, foreign_key: :doi, optional: true

  searchable if: :completed? do
    string :id
    string :collection_id
    string :source_reference_id
    string :source_name, multiple: true
    string :source_url
    string :explorer_url
    integer :cell_count

    string :authors, multiple: true do
      study&.authors || []
    end

    text :authors do
      study&.authors || []
    end

    # Basic string fields for direct name matches
    ASSOCIATION_METHODS.each do |category, method|
      string method, multiple: true do
        send(method).map(&:name)
      end
    end

    # Special hierarchical fields for organisms
    string :organism_ancestors, multiple: true do
      organisms.includes(:ontology_term).flat_map do |organism|
        if organism.ontology_term.present?
          ancestor_names = organism.ontology_term.all_ancestors.flat_map do |ancestor_term|
            Organism.where(ontology_term_id: ancestor_term.id).pluck(:name)
          end
          [organism.name] + ancestor_names
        else
          [organism.name]
        end
      end.uniq
    end

    # Ontology-aware fields with identifiers and ancestors (excluding Organism)
    ASSOCIATION_METHODS.except(Organism).each do |category, method|
      string "#{method}_ontology", multiple: true do
        send(method).includes(:ontology_term).flat_map do |item|
          terms = [item.ontology_term&.identifier]
          terms += item.ontology_term&.all_ancestors&.map(&:identifier) || []
          terms.compact
        end
      end
    end

    text :text_search do
      [
        ASSOCIATION_METHODS.values.flat_map do |method|
          send(method).includes(:ontology_term).map do |item|
            [
              item.name,
              item.ontology_term&.name
            ]
          end
        end,
        source_name,
        study&.authors
      ].flatten.compact.join(" ")
    end
  end

  def associated_category_items_for(category)
    association_method = ASSOCIATION_METHODS[category]
    raise ArgumentError, "Invalid category: #{category}. Must be one of: #{CATEGORIES.join(', ')}" unless association_method
    send(association_method)
  end
end
