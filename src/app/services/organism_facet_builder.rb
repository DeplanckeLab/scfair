class OrganismFacetBuilder
  def self.build_from_facets(search)
    new(search).build
  end

  def initialize(search)
    @search = search
  end

  def build
    return [] unless @search&.facet(:organisms)

    unfiltered_search = Dataset.search do
      facet :organisms, sort: :count
    end

    @organism_counts = collect_organism_counts(unfiltered_search)
    build_hierarchy
  end

  private

  def collect_organism_counts(search)
    search.facet(:organisms).rows.each_with_object({}) do |row, counts|
      counts[row.value] = row.count if row.value.present?
    end
  end

  def find_parent(organism_name)
    @organism_counts.keys
      .select { |p| p != organism_name && organism_name.start_with?("#{p} ") }
      .max_by(&:length)
  end

  def build_hierarchy
    parents, children = @organism_counts.keys.partition do |name|
      find_parent(name).nil?
    end

    parents.sort_by { |name| [-@organism_counts[name], name] }.flat_map do |parent|
      parent_node = {
        name: parent,
        count: @organism_counts[parent],
        level: 0,
        is_leaf: true
      }

      children_of_parent = children.select { |child| child.start_with?("#{parent} ") }

      if children_of_parent.any?
        parent_node[:is_leaf] = false

        [parent_node] + children_of_parent.sort_by { |name| [-@organism_counts[name], name] }.map do |child|
          {
            name: child,
            count: @organism_counts[child],
            level: 1,
            is_leaf: true
          }
        end
      else
        [parent_node]
      end
    end
  end
end