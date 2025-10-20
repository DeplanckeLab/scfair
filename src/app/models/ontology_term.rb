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

  class << self
    def scope_ids_for_category(category)
      model = case category.to_s
              when "organism" then Organism
              when "cell_type" then CellType
              when "tissue" then Tissue
              when "developmental_stage" then DevelopmentalStage
              when "disease" then Disease
              when "sex" then Sex
              when "technology" then Technology
              else nil
              end
      return [] unless model

      cache_key = ["ontology:scope_ids", category, model.maximum(:updated_at)&.to_i, model.count].join(":")
      Rails.cache.fetch(cache_key, expires_in: 6.hours) do
        model.where.not(ontology_term_id: nil).distinct.pluck(:ontology_term_id)
      end
    end

    def ancestors_for_ids(identifiers)
      return [] if identifiers.blank?
      cache_key = ["ontology:ancestors_for", identifiers.sort].join(":")
      Rails.cache.fetch(cache_key, expires_in: 12.hours) do
        terms = where(identifier: identifiers)
        terms.flat_map { |t| t.all_ancestors.map(&:identifier) }.compact.uniq
      end
    end

    def names_for_ids(identifiers)
      return [] if identifiers.blank?
      where(identifier: identifiers).pluck(:name)
    end

    def children_ids(category: nil, parent_id: nil)
      scoped_term_ids = scope_ids_for_category(category)
      return [] if scoped_term_ids.blank?

      if parent_id.present?
        parent = find_by(identifier: parent_id)
        return [] unless parent
        rels = OntologyTermRelationship.where(parent_id: parent.id, child_id: scoped_term_ids)
        child_ids = rels.joins(:child).pluck('ontology_terms.identifier')
        child_ids
      else
        children_with_parents_in_scope = OntologyTermRelationship.where(child_id: scoped_term_ids, parent_id: scoped_term_ids).distinct.pluck(:child_id)
        root_ids = scoped_term_ids - children_with_parents_in_scope
        where(id: root_ids).pluck(:identifier)
      end
    end

    def has_children?(identifier)
      term = find_by(identifier: identifier)
      return false unless term
      term.children.exists?
    end

    def identifiers_with_children_in_category(category, identifiers)
      return Set.new if identifiers.blank?
      scoped_term_ids = scope_ids_for_category(category)
      return Set.new if scoped_term_ids.blank?
      rows = joins(:child_relationships)
             .where(identifier: identifiers)
             .where('ontology_term_relationships.child_id IN (?)', scoped_term_ids)
             .distinct
             .pluck(:identifier)
      rows.to_set
    end
  end
end
