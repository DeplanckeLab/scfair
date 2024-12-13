module ApplicationHelper
  def extract_domain(url)
    return nil if url.blank?
    URI.parse(url).host.gsub(/^www\./, "")
  rescue URI::InvalidURIError
    nil
  end
end
