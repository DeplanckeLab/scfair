require "net/http"
require "json"
require "uri"

# Imports ASAP standalone compliance checks for Bgee URLs where
# "/ftp/current/" is replaced by "/ftp/16/" (Bgee release 16 mirrors).
# Checks are stored by source_url only (not linked to file_resources) so
# they do not disturb current-Bgee linked checks.
class BgeeV16ComplianceCheckImporter
  DEFAULT_BASE_URL = "https://asap-test.epfl.ch".freeze

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
    scope = FileResource
            .joins(dataset: :source)
            .where(sources: { slug: "bgee" })
            .where("file_resources.url LIKE ?", "%#{ComplianceCheckStats::BGEE_CURRENT_FTP_SEGMENT}%")
            .order("file_resources.created_at")
    scope = scope.limit(limit) if limit&.positive?

    total = scope.count
    puts "Looking up #{total} Bgee v16 URLs against #{base_url}/compliance/checks (dry_run=#{dry_run})"

    scope.find_each.with_index(1) do |file_resource, index|
      import_for_file_resource(file_resource)
      if (index % 20).zero?
        puts "progress #{index}/#{total} imported=#{imported} updated=#{updated} missing=#{missing} errors=#{errors.size}"
      end
    end

    summary
    errors.empty?
  end

  private

  def import_for_file_resource(file_resource)
    source_url = ComplianceCheckStats.bgee_v16_source_url(file_resource.url)
    if source_url == file_resource.url
      @errors << "#{file_resource.url}: could not derive Bgee v16 URL"
      return
    end

    payload = lookup(source_url)
    if payload.nil?
      @missing += 1
      return
    end

    attrs = attributes_from_payload(payload)

    if dry_run
      @imported += 1
      return
    end

    record = ComplianceCheck.find_or_initialize_by(asap_id: attrs[:asap_id])
    was_new = record.new_record?
    record.assign_attributes(attrs)
    record.save!

    if was_new
      @imported += 1
    else
      @updated += 1
    end
  rescue => e
    @errors << "#{file_resource.url}: #{e.message}"
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

  def attributes_from_payload(payload)
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
      file_resource_id: nil
    }
  end

  def summary
    puts "Done. imported=#{imported} updated=#{updated} missing=#{missing} errors=#{errors.size}"
    errors.first(20).each { |message| puts "  error: #{message}" }
  end
end
