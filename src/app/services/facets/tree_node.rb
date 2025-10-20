module Facets
  class TreeNode
    attr_reader :id, :name, :count, :has_children, :has_selected_children

    def initialize(id:, name:, count:, has_children: false, has_selected_children: false)
      @id = id
      @name = name
      @count = count
      @has_children = has_children
      @has_selected_children = has_selected_children
    end

    def to_h
      {
        id: @id,
        name: @name,
        count: @count,
        has_children: @has_children,
        has_selected_children: @has_selected_children
      }
    end

    def selected?(param_ids)
      param_ids.include?(@id.to_s)
    end
  end
end
