# frozen_string_literal: true

class FacetPresenter
  attr_reader :facet, :selection

  delegate :key, :tree?, :flat?, :display_name, :param_key, to: :facet

  def initialize(facet, data, selection = nil)
    @facet = facet
    @raw_data = data
    @selection = selection || FacetSelection.new
  end

  def nodes
    @nodes ||= case @raw_data
               when Hash then @raw_data[:nodes] || []
               when Array then @raw_data
               else []
    end
  end

  def pagination
    @pagination ||= @raw_data[:pagination] if @raw_data.is_a?(Hash)
  end

  def paginated?
    pagination.present?
  end

  def has_more?
    pagination&.dig(:has_more) || false
  end

  def total
    pagination&.dig(:total) || nodes.size
  end

  def offset
    pagination&.dig(:offset) || 0
  end

  def limit
    pagination&.dig(:limit) || 30
  end

  def next_offset
    offset + nodes.size
  end

  def colors
    @colors ||= facet.color_settings
  end

  def to_view_hash
    {
      key: key.to_sym,
      type: tree? ? :tree : :flat,
      data: nodes,
      colors: colors,
      pagination: pagination
    }
  end

  def to_content_locals
    {
      facet: to_view_hash,
      pagination: pagination
    }
  end

  def to_pagination_locals
    {
      category: key.to_s,
      nodes: nodes,
      pagination: pagination,
      colors: colors
    }
  end

  def to_nodes_locals(level: 0, parent_id: nil)
    {
      category: key.to_s,
      nodes: nodes,
      level: level,
      colors: colors,
      parent_id: parent_id
    }
  end

  def to_children_locals(parent_id:, frame_id: nil)
    {
      category: key.to_s,
      parent_id: parent_id,
      nodes: nodes,
      level: 1,
      colors: colors,
      frame_id: frame_id
    }
  end

  def empty?
    nodes.empty?
  end

  def any?
    nodes.any?
  end

  def selected_count
    selection.count(key)
  end

  def has_selections?
    selection.selected?(key)
  end

  def node_selected?(node_id)
    selection.value_selected?(key, node_id)
  end
end
