class OntologyTerm < ApplicationRecord
  has_many :sexes
  has_many :cell_types
  has_many :developmental_stages
  has_many :diseases
  has_many :organisms
  has_many :technologies
  has_many :tissues

  has_many :child_relationships, class_name: 'OntologyTermRelationship',
           foreign_key: :parent_id
  has_many :parent_relationships, class_name: 'OntologyTermRelationship',
           foreign_key: :child_id
           
  has_many :children, through: :child_relationships, source: :child
  has_many :parents, through: :parent_relationships, source: :parent


  validates :identifier, presence: true, uniqueness: true

  def all_ancestors
    visited = Set.new
    queue = parents.to_a
    ancestors = []

    while (term = queue.shift)
      next if visited.include?(term.id)
      visited.add(term.id)
      ancestors << term
      queue.concat(term.parents.to_a)
    end

    ancestors
  end
end
