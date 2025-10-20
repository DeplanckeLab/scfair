module ApplicationHelper
  def extract_domain(url)
    return nil if url.blank?
    URI.parse(url).host.gsub(/^www\./, "")
  rescue URI::InvalidURIError
    nil
  end

  def facet_params
    allowed_keys = Facets::Catalog.all.map { |f| Facets::Catalog.param_key(f[:key]).to_s }
    allowed_keys += %w[search sort page per]
    
    params.slice(*allowed_keys).permit!.to_h.symbolize_keys
  end

  def safe_dom_id(id)
    return "root" if id.blank?
    id.to_s.parameterize(separator: "_")
  end

  def facet_color_classes(key)
    settings = Facets::Catalog.color_settings(key)
    {
      badge: "#{settings[:bg_text]} #{settings[:text_color]}",
      checkbox: settings[:bg_circle].gsub('bg-', 'text-').gsub('500', '600'),
      focus_ring: settings[:bg_circle].gsub('bg-', 'focus:ring-'),
      button_text: settings[:bg_circle].gsub('bg-', 'text-').gsub('500', '600'),
      button_hover_text: settings[:bg_circle].gsub('bg-', 'hover:text-').gsub('500', '800'),
      button_hover_bg: settings[:bg_text].gsub('100', '50')
    }
  end

  def dom_id_for_nodes(category, parent_id)
    safe_parent = parent_id.present? ? safe_dom_id(parent_id) : "root"
    "facet_nodes_#{category}_#{safe_parent}"
  end
end
