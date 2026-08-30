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

  # Compact scFAIR status beside the dataset source title (same language as ASAP
  # catalog_candidate_scfair_compliance_list_icon). Links to the ASAP standalone
  # check result when a ComplianceCheck is linked.
  def dataset_scfair_compliance_list_icon(dataset)
    check = dataset.latest_compliance_check
    passed = check&.passed
    asap_id = check&.asap_id

    if passed == true
      icon_class = "text-green-600"
      title = "scFAIR compliant"
    else
      icon_class = "text-gray-300"
      title = if passed == false
                "scFAIR not compliant"
              else
                "scFAIR not yet validated"
              end
    end

    icon = content_tag(
      :svg,
      content_tag(
        :path,
        nil,
        fill_rule: "evenodd",
        clip_rule: "evenodd",
        d: "M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
      ),
      xmlns: "http://www.w3.org/2000/svg",
      class: "w-3 h-3 #{icon_class}",
      viewBox: "0 0 20 20",
      fill: "currentColor",
      "aria-hidden": true
    )
    wrapper_class = "inline-flex items-center shrink-0"

    if asap_id.present?
      link_to(
        icon,
        "#{asap_base_url}/standalone_compliance_checks/#{asap_id}",
        class: "#{wrapper_class} hover:opacity-80",
        title: "#{title} (open check)",
        target: "_blank",
        rel: "noopener noreferrer",
        data: { action: "click->card#stopPropagation" }
      )
    else
      content_tag(:span, icon, class: wrapper_class, title: title)
    end
  end

  private
    def asap_base_url
      ENV.fetch("ASAP_BASE_URL", "https://asap.epfl.ch").to_s.chomp("/")
    end

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
