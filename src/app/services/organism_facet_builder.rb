class OrganismFacetBuilder
  def self.build_from_facets(search)
    new(search).build
  end
  
  def initialize(search)
    @search = search
    @organism_counts = {}
    @organism_ancestor_map = {}
    @direct_parent_map = {}
  end
  
  def build
    return [] unless @search&.facet(:organisms)&.rows&.any?
    
    @organism_counts = {}
    @organism_ancestor_map = {}
    @direct_parent_map = {}
    
    collect_organism_counts
    collect_ancestor_data
    detect_parent_child_relationships
    build_direct_parent_map
    rebuild_ancestor_lists
    build_hierarchy
  end
  
  private
  
  def collect_organism_counts
    return unless @search&.facet(:organisms)&.rows
    
    @search.facet(:organisms).rows.each do |row|
      next unless row.value.present?
      
      @organism_counts[row.value] = row.count
    end
  end
  
  def collect_ancestor_data
    return if @organism_counts.nil? || @organism_counts.empty?
    
    organism_keys = @organism_counts.keys
    return if organism_keys.empty?
    
    batch_search = Dataset.search do
      with(:organisms, organism_keys)
      paginate per_page: 500
      field_list :organism_ancestors
    end
    
    batch_search.hits.each do |hit|
      next unless hit.respond_to?(:stored)
      
      ancestors_list = hit.stored(:organism_ancestors) || []
      
      ancestors_list.each do |organism_name|
        next if @organism_ancestor_map.key?(organism_name) || !@organism_counts.key?(organism_name)
        
        ancestors = ancestors_list.select { |a| a != organism_name && @organism_counts.key?(a) }
        @organism_ancestor_map[organism_name] = ancestors
      end
    end
    
    @organism_counts.keys.each do |organism_name|
      @organism_ancestor_map[organism_name] ||= []
    end
  end
  
  def detect_parent_child_relationships
    @organism_counts.keys.each do |child_name|
      next if @organism_ancestor_map[child_name].present?
      
      potential_parents = @organism_counts.keys.select do |parent_name|
        parent_name.length < child_name.length && 
        child_name.start_with?("#{parent_name} ") && 
        child_name.split.size > parent_name.split.size
      end
      
      if potential_parents.any?
        most_specific_parent = potential_parents.max_by(&:length)
        @organism_ancestor_map[child_name] = [most_specific_parent]
      end
    end
  end
  
  def build_direct_parent_map
    @organism_ancestor_map.each do |organism_name, ancestors|
      next if ancestors.empty?
      
      sorted_ancestors = ancestors.sort_by { |a| [-1 * a.split.size, -1 * a.length] }
      @direct_parent_map[organism_name] = sorted_ancestors.first
    end
  end
  
  def rebuild_ancestor_lists
    @organism_counts.keys.each do |organism_name|
      ancestors = []
      current = organism_name
      
      while parent = @direct_parent_map[current]
        ancestors.unshift(parent)
        current = parent
      end
      
      @organism_ancestor_map[organism_name] = ancestors
    end
  end
  
  def build_hierarchy
    return [] if @organism_ancestor_map.nil? || @organism_ancestor_map.empty?
    return [] if @organism_counts.nil? || @organism_counts.empty?
    
    organism_hierarchy = {}
    ancestor_child_map = Hash.new { |h, k| h[k] = [] }
    
    @organism_ancestor_map.each do |organism_name, ancestors|
      level = ancestors.size
      lowercase_ancestors = ancestors.map(&:downcase) rescue []
      
      organism_hierarchy[organism_name] = {
        name: organism_name,
        count: @organism_counts.fetch(organism_name, 0),
        level: level,
        ancestors: ancestors,
        lowercase_ancestors: lowercase_ancestors,
        is_leaf: true
      }
      
      if ancestors.any?
        parent = @direct_parent_map[organism_name]
        ancestor_child_map[parent] << organism_name if parent
      end
    end
    
    update_leaf_status(organism_hierarchy, ancestor_child_map)
    
    root_nodes = organism_hierarchy.values.select { |node| node[:ancestors].empty? }
    sorted_roots = root_nodes.sort_by { |node| [-node[:count], node[:name]] }
    
    facet_rows = []
    process_hierarchy_nodes(sorted_roots, ancestor_child_map, organism_hierarchy, facet_rows)
    facet_rows
  end
  
  def update_leaf_status(organism_hierarchy, ancestor_child_map)
    ancestor_child_map.each do |parent, children|
      if organism_hierarchy.key?(parent) && children.any?
        organism_hierarchy[parent][:is_leaf] = false
      end
    end
  end
  
  def process_hierarchy_nodes(nodes, ancestor_child_map, organism_hierarchy, results)
    nodes.each do |node|
      results << node
      
      children = ancestor_child_map[node[:name]]
      if children.any?
        sorted_children = children.map { |name| organism_hierarchy[name] }
                               .compact
                               .sort_by { |child| [-child[:count], child[:name]] }
        
        process_hierarchy_nodes(sorted_children, ancestor_child_map, organism_hierarchy, results)
      end
    end
  end
end 