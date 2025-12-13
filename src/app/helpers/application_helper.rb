module ApplicationHelper
  def extract_domain(url)
    return nil if url.blank?
    URI.parse(url).host.gsub(/^www\./, "")
  rescue URI::InvalidURIError
    nil
  end

  def facet_params
    allowed_keys = Facet.all.map { |f| f.param_key.to_s }
    allowed_keys += %w[search sort page per]

    params.slice(*allowed_keys).permit!.to_h.symbolize_keys
  end

  def safe_dom_id(id)
    return "root" if id.blank?
    id.to_s.parameterize(separator: "_")
  end

  def facet_color_classes(key)
    facet = Facet.find(key)
    settings = facet&.color_settings || default_facet_colors
    {
      badge: "#{settings[:bg_text]} #{settings[:text_color]}",
      checkbox_checked: settings[:checkbox_checked],
      focus_ring: settings[:focus_ring],
      button_text: settings[:bg_circle].gsub("bg-", "text-").gsub("500", "600"),
      button_hover_text: settings[:bg_circle].gsub("bg-", "hover:text-").gsub("500", "800"),
      button_hover_bg: settings[:bg_text].gsub("100", "50")
    }
  end

  def dom_id_for_nodes(category, parent_id)
    safe_parent = parent_id.present? ? safe_dom_id(parent_id) : "root"
    "facet_nodes_#{category}_#{safe_parent}"
  end

  private
    def default_facet_colors
      {
        bg_circle: "bg-blue-500",
        bg_text: "bg-blue-100",
        text_color: "text-blue-800",
        checkbox_checked: "text-blue-600",
        focus_ring: "focus:ring-blue-300"
      }
    end
end
