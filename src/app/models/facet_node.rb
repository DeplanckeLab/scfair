# frozen_string_literal: true

# Value object representing a node in a facet tree or flat list.
# Immutable data container with no behavior beyond attribute access.
class FacetNode
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :string
  attribute :name, :string
  attribute :count, :integer, default: 0
  attribute :has_children, :boolean, default: false
  attribute :has_selected_children, :boolean, default: false

  def to_h
    {
      id: id,
      name: name,
      count: count,
      has_children: has_children,
      has_selected_children: has_selected_children
    }
  end

  def selected?(selected_ids)
    Array(selected_ids).map(&:to_s).include?(id.to_s)
  end
end
