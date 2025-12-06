class CellType < ApplicationRecord
  include OntologyValidated
  ALLOWED_ONTOLOGIES = %w[CL FBbt WBbt ZFA].freeze

  # FBbt cell root term - all valid FBbt cell types must be descendants of this
  FBBT_CELL_ROOT_IDENTIFIER = "FBbt:00007002".freeze

  belongs_to :ontology_term, optional: true

  has_and_belongs_to_many :datasets

  validates :name, uniqueness: { scope: :ontology_term_id }

  # Validates that an identifier is a valid cell type term
  # For FBbt terms, checks if it's a descendant of the FBbt cell root
  def self.valid_cell_type_term?(identifier)
    return false unless valid_ontology?(identifier)

    prefix = extract_ontology_prefix(identifier)
    return true unless prefix == "FBbt"

    # For FBbt terms, must be descendant of cell root
    fbbt_cell_descendant?(identifier)
  end

  # Checks if an FBbt identifier is a descendant of the FBbt cell root term
  def self.fbbt_cell_descendant?(identifier)
    ontology_term = OntologyTerm.find_by(identifier: identifier)
    return false unless ontology_term

    cell_root = OntologyTerm.find_by(identifier: FBBT_CELL_ROOT_IDENTIFIER)
    return false unless cell_root

    # Check if this term is a descendant of the cell root
    is_descendant_of?(ontology_term.id, cell_root.id)
  end

  # Recursively checks if child_id is a descendant of ancestor_id
  def self.is_descendant_of?(child_id, ancestor_id, visited = Set.new)
    return true if child_id == ancestor_id
    return false if visited.include?(child_id)

    visited.add(child_id)

    parent_ids = OntologyTermRelationship.where(child_id: child_id).pluck(:parent_id)
    parent_ids.any? { |pid| is_descendant_of?(pid, ancestor_id, visited) }
  end

  def self.color_settings
    {
      bg_circle: "bg-green-500",
      bg_text: "bg-green-100",
      text_color: "text-green-800",
    }
  end

  def self.display_name
    "Cell Type"
  end
end
