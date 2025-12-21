# frozen_string_literal: true

class FacetSelection
  include ActiveModel::Model

  attr_reader :selections, :search_text, :sort_order

  def initialize(selections: {}, search_text: nil, sort_order: :relevance)
    @selections = normalize_selections(selections)
    @search_text = search_text.to_s.strip.presence
    @sort_order = sort_order&.to_sym || :relevance
  end

  def self.from_params(params)
    new(
      selections: extract_selections(params),
      search_text: params[:search],
      sort_order: params[:sort]
    )
  end

  def self.extract_selections(params)
    Facet.all.each_with_object({}) do |facet, hash|
      values = Array(params[facet.param_key]).map(&:to_s).reject(&:blank?)
      hash[facet.key.to_sym] = values if values.any?
    end
  end

  def as_params
    {}.tap do |p|
      p[:search] = search_text if search_text.present?
      p[:sort] = sort_order unless sort_order == :relevance

      selections.each do |key, values|
        next if values.empty?

        facet = Facet.find(key)
        p[facet.param_key] = values if facet
      end
    end
  end

  def as_params_without(facet_key, value)
    new_selections = deep_dup_selections
    facet_key = facet_key.to_sym

    if new_selections[facet_key]
      new_selections[facet_key] -= [value.to_s]
      new_selections.delete(facet_key) if new_selections[facet_key].empty?
    end

    self.class.new(
      selections: new_selections,
      search_text: search_text,
      sort_order: sort_order
    ).as_params
  end

  def as_params_with(facet_key, value)
    new_selections = deep_dup_selections
    facet_key = facet_key.to_sym
    new_selections[facet_key] ||= []
    new_selections[facet_key] << value.to_s unless new_selections[facet_key].include?(value.to_s)

    self.class.new(
      selections: new_selections,
      search_text: search_text,
      sort_order: sort_order
    ).as_params
  end

  def selected?(facet_key)
    selections[facet_key.to_sym]&.any? || false
  end

  def value_selected?(facet_key, value)
    selected_ids(facet_key).include?(value.to_s)
  end

  def selected_ids(facet_key)
    selections[facet_key.to_sym] || []
  end

  def count(facet_key)
    selected_ids(facet_key).size
  end

  def total_count
    selections.values.sum(&:size)
  end

  def any?
    selections.values.any?(&:any?)
  end

  def searching?
    search_text.present?
  end

  def filtered?
    any? || searching?
  end

  def self.param_key_for(category)
    Facet.find(category)&.param_key || category.to_sym
  end

  def self.param_key_map
    Facet.all.each_with_object({}) do |facet, map|
      map[facet.key.to_sym] = facet.param_key
    end
  end

  private

    def normalize_selections(selections)
      selections.transform_keys(&:to_sym).transform_values do |values|
        Array(values).map(&:to_s).reject(&:blank?)
      end
    end

    def deep_dup_selections
      selections.transform_values(&:dup)
    end
end
