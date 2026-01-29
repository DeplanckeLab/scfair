# frozen_string_literal: true

class Facet::Tree
  def initialize(facet, params = {})
    @facet = facet
    @params = params.respond_to?(:with_indifferent_access) ? params.with_indifferent_access : params.to_h.with_indifferent_access
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

    all_filtered_ids = (term_ids + ancestor_ids).to_set

    candidates = build_candidates_with_groupings(term_ids, ancestor_ids, metadata)
    display_ids = compute_display_ids(candidates, counts, metadata)
    return empty_result(limit) if display_ids.empty?

    global_duplicates = compute_global_duplicate_names(metadata)

    nodes = node_builder.build(
      display_ids,
      counts[:ancestor],
      metadata,
      scoped_term_ids: all_filtered_ids,
      visible_roots: display_ids,
      global_duplicate_names: global_duplicates
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

    unfiltered_metadata = unfiltered_structure[:terms_metadata]

    filtered_metadata = lookup_terms((filtered_term_ids + filtered_ancestor_ids).uniq)
    metadata = unfiltered_metadata.merge(filtered_metadata)

    selected_ids = selected_term_ids
    if selected_ids.any?
      selected_metadata = lookup_terms(selected_ids)
      metadata = metadata.merge(selected_metadata)
    end

    all_filtered_ids = (filtered_term_ids + filtered_ancestor_ids).to_set

    candidates = build_candidates_with_groupings(filtered_term_ids, filtered_ancestor_ids, metadata)
    display_ids = compute_display_ids(candidates, counts, metadata)
    return empty_result(limit) if display_ids.empty?

    global_duplicates = compute_global_duplicate_names(metadata)

    nodes = node_builder.build(
      display_ids,
      counts[:ancestor],
      metadata,
      scoped_term_ids: all_filtered_ids,
      visible_roots: display_ids,
      global_duplicate_names: global_duplicates
    )

    paginator.paginate(nodes, limit: limit || nodes.size, offset: offset)
  end

  def process_children(aggregation, parent_id:, visible_roots: [], global_duplicate_names: nil, global_ancestor_ids: [])
    return [] unless aggregation

    buckets = extract_children_buckets(aggregation)
    return [] if buckets[:children].empty?

    counts = build_counts_for_children(buckets)

    children_term_ids = buckets[:children].map { |b| b["key"] }
    direct_term_ids = buckets[:direct].map { |b| b["key"] }
    all_ids = (children_term_ids + direct_term_ids + [parent_id]).uniq

    metadata = lookup_terms(all_ids)
    return [] if metadata.empty?

    selected_ids = selected_term_ids
    if selected_ids.any?
      selected_metadata = lookup_terms(selected_ids)
      metadata = metadata.merge(selected_metadata)
    end

    child_ids = metadata.dig(parent_id, :child_ids) || []
    children_in_scope = child_ids & children_term_ids

    children_to_show = children_in_scope - visible_roots

    children_in_scope_set = children_in_scope.to_set
    children_to_show = children_to_show.reject do |child_id|
      child_parent_ids = metadata.dig(child_id, :parent_ids) || []
      more_specific_parents = child_parent_ids.select do |pid|
        pid != parent_id && children_in_scope_set.include?(pid)
      end
      more_specific_parents.any?
    end

    return [] if children_to_show.empty?

    duplicates = global_duplicate_names || compute_global_duplicate_names(metadata)

    # Include global_ancestor_ids in scoped_ids to correctly compute has_children
    # Children may have descendants with datasets even if the children themselves don't appear in direct_term_ids
    all_scoped_ids = (children_term_ids + direct_term_ids + global_ancestor_ids).to_set
    nodes = node_builder.build(
      children_to_show,
      counts[:children],
      metadata,
      scoped_term_ids: all_scoped_ids,
      visible_roots: visible_roots,
      global_duplicate_names: duplicates
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

    def compute_global_duplicate_names(metadata)
      name_counts = Hash.new(0)
      metadata.each_value do |term_data|
        name = term_data[:name]&.to_s&.downcase&.capitalize&.downcase
        name_counts[name] += 1 if name
      end
      name_counts.select { |_, count| count > 1 }.keys.to_set
    end

    def compute_display_ids(term_ids, counts, metadata)
      DisplayFilter.compute_display_ids(term_ids, counts, metadata)
    end

    def build_candidates_with_groupings(term_ids, ancestor_ids, metadata)
      candidates = term_ids.to_set
      term_ids_set = term_ids.to_set

      ancestor_ids.each do |aid|
        next if candidates.include?(aid)

        child_ids = metadata.dig(aid, :child_ids) || []
        children_with_direct = child_ids.count { |cid| term_ids_set.include?(cid) }

        candidates.add(aid) if children_with_direct >= 2 && children_with_direct <= Facet::Tree::DisplayFilter::MAX_CHILDREN_FOR_GROUPING
      end

      candidates.to_a
    end
end
