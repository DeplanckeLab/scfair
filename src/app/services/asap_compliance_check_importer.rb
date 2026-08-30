require "net/http"
require "json"
require "uri"

class AsapComplianceCheckImporter
  DEFAULT_BASE_URL = "https://asap.epfl.ch".freeze

  attr_reader :base_url, :dry_run, :limit, :imported, :updated, :missing, :errors

  def initialize(base_url: ENV.fetch("ASAP_BASE_URL", DEFAULT_BASE_URL), dry_run: ENV["DRY_RUN"] == "1", limit: ENV["LIMIT"]&.to_i)
    @base_url = base_url.to_s.chomp("/")
    @dry_run = dry_run
    @limit = limit
    @imported = 0
    @updated = 0
    @missing = 0
    @errors = []
  end

  def perform
    scope = FileResource.order(:created_at)
    scope = scope.limit(limit) if limit&.positive?

    total = scope.count
    puts "Looking up #{total} file_resources against #{base_url}/compliance/checks (dry_run=#{dry_run})"

    scope.find_each.with_index(1) do |file_resource, index|
      import_for_file_resource(file_resource)
      puts "progress #{index}/#{total} imported=#{imported} updated=#{updated} missing=#{missing} errors=#{errors.size}" if (index % 200).zero?
    end

    summary
    errors.empty?
  end

  def import_for_file_resource(file_resource)
    urls = candidate_urls_for(file_resource.url)
    found_any = false

    urls.each do |url|
      record = upsert_from_url(url, file_resource: file_resource, count_missing: false)
      found_any = true if record
    end

    @missing += 1 unless found_any
  end

  def upsert_from_url(source_url, file_resource: nil, count_missing: true)
    payload = lookup(source_url)
    if payload.nil?
      @missing += 1 if count_missing
      return nil
    end

    file_resource ||= FileResource.find_by(url: source_url)
    file_resource ||= file_resource_for_asap_project_url(payload.fetch("source_url"))
    attrs = attributes_from_payload(payload, file_resource)

    if dry_run
      @imported += 1
      return attrs
    end

    record = ComplianceCheck.find_or_initialize_by(asap_id: attrs[:asap_id])
    was_new = record.new_record?
    record.assign_attributes(attrs)
    record.save!

    # A re-run on ASAP creates a new asap_id; keep only the latest check linked.
    if file_resource
      ComplianceCheck
        .where(file_resource_id: file_resource.id)
        .where.not(id: record.id)
        .update_all(file_resource_id: nil, updated_at: Time.current)
    end

    if was_new
      @imported += 1
    else
      @updated += 1
    end
    record
  rescue => e
    @errors << "#{source_url}: #{e.message}"
    nil
  end

  private

  def candidate_urls_for(url)
    urls = [url]
    uri = URI.parse(url)
    return urls unless uri.query

    params = URI.decode_www_form(uri.query).to_h
    filename = params["filename"]
    return urls if filename.blank?

    project_match = uri.path.match(%r{\A/projects/([^/]+)/get_file\z})
    return urls unless project_match

    project_key = project_match[1]
    basename = filename.split("/").last
    extension = File.extname(basename)
    stem = basename.delete_suffix(extension)

    # ASAP standalone checks for project looms are keyed with a URL-encoded slash
    # (parsing%2Foutput.loom), while scFAIR stores unencoded h5ad paths.
    variants = [
      filename,
      filename.gsub("/", "%2F"),
      "parsing/#{stem}#{extension}",
      "parsing%2F#{stem}#{extension}",
      "parsing/output.loom",
      "parsing%2Foutput.loom",
      "parsing/output.h5ad",
      "parsing%2Foutput.h5ad"
    ]

    variants.uniq.map do |fn|
      "#{uri.scheme}://#{uri.host}/projects/#{project_key}/get_file?filename=#{fn}"
    end
  rescue URI::InvalidURIError
    [url]
  end

  def file_resource_for_asap_project_url(source_url)
    match = source_url.to_s.match(%r{/projects/([^/]+)/get_file})
    return nil unless match

    project_key = match[1]
    FileResource
      .joins(dataset: :source)
      .where(sources: { slug: "asap" })
      .where("file_resources.url LIKE ?", "%/projects/#{project_key}/get_file%")
      .order(:created_at)
      .first
  end

  def lookup(source_url)
    uri = URI("#{base_url}/compliance/checks")
    uri.query = URI.encode_www_form(source_url: source_url)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 30, read_timeout: 60) do |http|
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      http.request(request)
    end

    case response.code.to_i
    when 200
      JSON.parse(response.body)
    when 404
      nil
    else
      raise "HTTP #{response.code}: #{response.body.to_s.truncate(200)}"
    end
  end

  def attributes_from_payload(payload, file_resource)
    {
      asap_id: payload.fetch("id"),
      task_id: payload["task_id"],
      filename: payload["filename"],
      source_url: payload.fetch("source_url"),
      schema_id: payload["schema_id"],
      format: payload["format"],
      passed: payload["passed"],
      status: payload["status"],
      checked_at: payload["checked_at"],
      admin_run: payload.fetch("admin_run", false),
      result: payload["result"] || {},
      file_resource_id: file_resource&.id
    }
  end

  def summary
    puts "Done. imported=#{imported} updated=#{updated} missing=#{missing} errors=#{errors.size}"
    errors.first(20).each { |message| puts "  error: #{message}" }
  end
end
