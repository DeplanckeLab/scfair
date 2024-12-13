class Dataset < ApplicationRecord
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

  has_and_belongs_to_many :sexes
  has_and_belongs_to_many :cell_types
  has_and_belongs_to_many :tissues
  has_and_belongs_to_many :developmental_stages
  has_and_belongs_to_many :organisms
  has_and_belongs_to_many :diseases
  has_and_belongs_to_many :technologies

  has_many :links, class_name: "DatasetLink"
  has_many :file_resources

  belongs_to :study, primary_key: :doi, foreign_key: :doi, optional: true

  searchable do
    string :id
    string :collection_id
    string :source_reference_id
    string :source_name
    string :source_url
    string :explorer_url
    string :doi
    integer :cell_count
    string :source_name

    string :sexes, multiple: true do
      sexes.map(&:name)
    end
    
    string :cell_types, multiple: true do
      cell_types.map(&:name)
    end
    
    string :tissues, multiple: true do
      tissues.map(&:name)
    end
    
    string :developmental_stages, multiple: true do
      developmental_stages.map(&:name)
    end
    
    string :organisms, multiple: true do
      organisms.map(&:name)
    end
    
    string :diseases, multiple: true do
      diseases.map(&:name)
    end
    
    string :technologies, multiple: true do
      technologies.map(&:name)
    end

    text :text_search do
      [
        sexes.map(&:name),
        cell_types.map(&:name),
        tissues.map(&:name),
        developmental_stages.map(&:name),
        organisms.map(&:name),
        diseases.map(&:name),
        technologies.map(&:name),
        source_name
      ].flatten.compact.join(" ")
    end
  end

  def associated_category_items_for(category)
    association_method = ASSOCIATION_METHODS[category]
    raise ArgumentError, "Invalid category: #{category}. Must be one of: #{CATEGORIES.join(', ')}" unless association_method
    send(association_method)
  end
end
