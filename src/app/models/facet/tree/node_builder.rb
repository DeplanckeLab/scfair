# frozen_string_literal: true

class Facet::Tree::NodeBuilder
  def initialize(facet, params = {})
    @facet = facet
    @params = params
    @selected_ids = extract_selected_ids.to_set
  end

  def build(display_ids, counts_by_id, metadata, scoped_term_ids:, visible_roots: [], global_duplicate_names: nil)
    excluded_children = visible_roots.to_set
    nodes_with_children = identify_nodes_with_children(display_ids, metadata, scoped_term_ids, excluded_children)
    nodes_with_selected_children = identify_nodes_with_selected_children(metadata)

    nodes = display_ids.map do |id|
      build_node(id, counts_by_id, metadata, nodes_with_children, nodes_with_selected_children)
    end

    label_duplicate_names(nodes, metadata, global_duplicate_names)
  end

  private
    def extract_selected_ids
      param_key = @facet.param_key
      Array(@params[param_key]).map(&:to_s)
    end

    def build_node(id, counts_by_id, metadata, nodes_with_children, nodes_with_selected_children)
      raw_name = metadata.dig(id, :name) || id
      FacetNode.new(
        id: id,
        name: raw_name.to_s.capitalize,
        count: counts_by_id[id] || 0,
        has_children: nodes_with_children.include?(id),
        has_selected_children: nodes_with_selected_children.include?(id)
      )
    end

    def identify_nodes_with_children(display_ids, metadata, scoped_term_ids, excluded_children)
      display_ids.each_with_object(Set.new) do |id, result|
        child_ids = metadata.dig(id, :child_ids) || []
        visible_children = (child_ids.to_set & scoped_term_ids) - excluded_children
        result.add(id) if visible_children.any?
      end
    end

    def identify_nodes_with_selected_children(metadata)
      return Set.new if @selected_ids.empty?

      @selected_ids.each_with_object(Set.new) do |selected_id, ancestors|
        trace_ancestors(selected_id, metadata, ancestors)
      end
    end

    def trace_ancestors(term_id, metadata, ancestors, visited = Set.new)
      return if visited.include?(term_id)
      visited.add(term_id)

      parent_ids = metadata.dig(term_id, :parent_ids) || []
      parent_ids.each do |parent_id|
        ancestors.add(parent_id)
        trace_ancestors(parent_id, metadata, ancestors, visited)
      end
    end

    def label_duplicate_names(nodes, metadata, global_duplicate_names = nil)
      if global_duplicate_names
        duplicate_names = global_duplicate_names
      else
        by_name = nodes.group_by { |n| n.name&.downcase }
        duplicate_names = by_name.select { |_, group| group.size > 1 }.keys.to_set
      end

      return nodes if duplicate_names.empty?

      nodes.each do |node|
        next unless duplicate_names.include?(node.name&.downcase)

        identifier = metadata.dig(node.id, :identifier)
        prefix = extract_ontology_prefix(identifier)
        node.name = "#{node.name} (#{prefix})" if prefix
      end

      nodes
    end

    def extract_ontology_prefix(identifier)
      return nil if identifier.blank?
      identifier.split(":").first
    end
end
