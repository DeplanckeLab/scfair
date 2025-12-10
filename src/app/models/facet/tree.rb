# frozen_string_literal: true

class Facet::Tree
  def initialize(facet, params = {})
    @facet = facet
    @params = params
    @category = facet.key.to_s
  end

  def process(aggregation, limit: nil, offset: 0)
    return empty_result(limit) unless aggregation

    buckets = extract_buckets(aggregation)
    return empty_result(limit) if buckets[:direct].empty?

    counts = build_counts(buckets)
    term_ids = buckets[:direct].map { |b| b["key"] }
    ancestor_ids = buckets[:ancestor].map { |b| b["key"] }
    all_ids = (term_ids + ancestor_ids).uniq

    metadata = lookup_terms(all_ids)
    return empty_result(limit) if metadata.empty?

    selected_ids = selected_term_ids
    if selected_ids.any?
      selected_metadata = lookup_terms(selected_ids)
      metadata = metadata.merge(selected_metadata)
    end

    candidates = build_candidates_with_virtual_parents(term_ids, ancestor_ids, counts, metadata)

    visible_roots = root_identifier(metadata).identify(candidates, counts[:ancestor], counts[:direct])
    return empty_result(limit) if visible_roots.empty?

    all_filtered_ids = (term_ids + ancestor_ids).to_set
    display_ids = visible_roots & ancestor_ids

    if selected_ids.any?
      ancestor_paths = build_ancestor_paths(selected_ids, visible_roots, all_filtered_ids, metadata)
      display_ids = (display_ids | ancestor_paths.to_a)
      display_ids = filter_to_root_level_only(display_ids, metadata)
    end

    display_ids = display_ids.select { |id| counts[:ancestor][id].to_i > 0 }
    return empty_result(limit) if display_ids.empty?

    nodes = node_builder.build(
      display_ids,
      counts[:ancestor],
      metadata,
      scoped_term_ids: all_filtered_ids,
      visible_roots: visible_roots
    )

    if limit
      paginator.paginate(nodes, limit: limit, offset: offset)
    else
      nodes.map(&:to_h)
    end
  end

  def process_with_structure(filtered_aggregation, unfiltered_structure, limit: nil, offset: 0)
    return empty_result(limit) unless filtered_aggregation

    buckets = extract_buckets(filtered_aggregation)
    return empty_result(limit) if buckets[:direct].empty?

    counts = build_counts(buckets)
    filtered_term_ids = buckets[:direct].map { |b| b["key"] }
    filtered_ancestor_ids = buckets[:ancestor].map { |b| b["key"] }

    visible_roots = unfiltered_structure[:visible_roots]
    unfiltered_metadata = unfiltered_structure[:terms_metadata]

    filtered_metadata = lookup_terms((filtered_term_ids + filtered_ancestor_ids).uniq)
    metadata = unfiltered_metadata.merge(filtered_metadata)

    selected_ids = selected_term_ids
    if selected_ids.any?
      selected_metadata = lookup_terms(selected_ids)
      metadata = metadata.merge(selected_metadata)
    end

    display_ids = visible_roots & filtered_ancestor_ids
    all_filtered_ids = (filtered_term_ids + filtered_ancestor_ids).to_set

    if selected_ids.any?
      ancestor_paths = build_ancestor_paths(selected_ids, visible_roots, all_filtered_ids, metadata)
      display_ids = (display_ids | ancestor_paths.to_a)
      display_ids = filter_to_root_level_only(display_ids, metadata)
    end

    display_ids = display_ids.select { |id| counts[:ancestor][id].to_i > 0 }
    return empty_result(limit) if display_ids.empty?

    nodes = node_builder.build(
      display_ids,
      counts[:ancestor],
      metadata,
      scoped_term_ids: all_filtered_ids,
      visible_roots: visible_roots
    )

    paginator.paginate(nodes, limit: limit || nodes.size, offset: offset)
  end

  def process_children(aggregation, parent_id:, visible_roots: [])
    return [] unless aggregation

    buckets = extract_children_buckets(aggregation)
    return [] if buckets[:direct].empty?

    counts = build_counts_for_children(buckets)
    term_ids = buckets[:direct].map { |b| b["key"] }
    all_ids = (term_ids + buckets[:children].map { |b| b["key"] } + [parent_id]).uniq

    metadata = lookup_terms(all_ids)
    return [] if metadata.empty?

    selected_ids = selected_term_ids
    if selected_ids.any?
      selected_metadata = lookup_terms(selected_ids)
      metadata = metadata.merge(selected_metadata)
    end

    child_ids = metadata.dig(parent_id, :child_ids) || []
    children_in_scope = child_ids & term_ids
    children_to_show = children_in_scope - visible_roots

    return [] if children_to_show.empty?

    nodes = node_builder.build(
      children_to_show,
      counts[:children],
      metadata,
      scoped_term_ids: term_ids.to_set,
      visible_roots: visible_roots
    )

    nodes.map(&:to_h)
  end

  private
    def extract_buckets(aggregation)
      {
        ancestor: aggregation.dig("ancestor_terms", "buckets") || [],
        direct: aggregation.dig("direct_terms", "buckets") || []
      }
    end

    def extract_children_buckets(aggregation)
      {
        children: aggregation.dig("children_terms", "buckets") || [],
        direct: aggregation.dig("direct_terms", "buckets") || []
      }
    end

    def build_counts(buckets)
      {
        ancestor: buckets[:ancestor].to_h { |b| [b["key"], b["doc_count"]] },
        direct: buckets[:direct].to_h { |b| [b["key"], b["doc_count"]] }
      }
    end

    def build_counts_for_children(buckets)
      {
        children: buckets[:children].to_h { |b| [b["key"], b["doc_count"]] },
        direct: buckets[:direct].to_h { |b| [b["key"], b["doc_count"]] }
      }
    end

    def lookup_terms(ids)
      Search::OntologyTermLookup.fetch_terms(ids)
    end

    def root_identifier(metadata)
      Facet::Tree::RootIdentifier.new(metadata)
    end

    def node_builder
      @node_builder ||= Facet::Tree::NodeBuilder.new(@facet, @params)
    end

    def paginator
      @paginator ||= Facet::Tree::Paginator.new(@params)
    end

    def empty_result(limit)
      if limit
        { nodes: [], pagination: { total: 0, offset: 0, limit: limit, has_more: false } }
      else
        []
      end
    end

    def selected_term_ids
      param_key = @facet.param_key
      Array(@params[param_key])
    end

    def build_ancestor_paths(selected_ids, visible_roots, valid_ids, metadata)
      paths = Set.new
      visible_roots_set = visible_roots.to_set

      selected_ids.each do |selected_id|
        next unless valid_ids.include?(selected_id)

        current_ids = [selected_id]
        visited = Set.new

        while current_ids.any?
          next_ids = []
          current_ids.each do |current_id|
            next if visited.include?(current_id)
            visited.add(current_id)

            if current_id == selected_id
              parent_ids = metadata.dig(current_id, :parent_ids) || []
              next_ids.concat(parent_ids.select { |pid| valid_ids.include?(pid) })
              next
            end

            if visible_roots_set.include?(current_id)
              paths.add(current_id)
              next
            end

            paths.add(current_id) if valid_ids.include?(current_id)

            parent_ids = metadata.dig(current_id, :parent_ids) || []
            next_ids.concat(parent_ids.select { |pid| valid_ids.include?(pid) })
          end
          current_ids = next_ids.uniq
        end
      end

      paths
    end

    def filter_to_root_level_only(display_ids, metadata)
      display_ids_set = display_ids.to_set

      display_ids.reject do |id|
        parent_ids = metadata.dig(id, :parent_ids) || []
        parent_ids.any? { |pid| display_ids_set.include?(pid) }
      end
    end

    def build_candidates_with_virtual_parents(term_ids, ancestor_ids, counts, metadata)
      candidates = term_ids.to_set
      ancestor_set = ancestor_ids.to_set

      term_ids.each do |child_id|
        parent_ids = metadata.dig(child_id, :parent_ids) || []
        parent_ids.each do |pid|
          next unless ancestor_set.include?(pid)
          next if candidates.include?(pid)
          next unless counts[:ancestor][pid].to_i > 0
          next unless counts[:direct][pid].to_i > 0

          candidates.add(pid)
        end
      end

      candidates.to_a
    end

end
