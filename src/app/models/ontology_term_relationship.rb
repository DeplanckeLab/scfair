class OntologyTermRelationship < ApplicationRecord
  belongs_to :parent, class_name: "OntologyTerm"
  belongs_to :child, class_name: "OntologyTerm"

  validates :parent_id, presence: true
  validates :child_id, presence: true
  validates :relationship_type, presence: true, 
            inclusion: { in: ["is_a", "part_of"] }
  validates :parent_id, uniqueness: { scope: :child_id }
end
