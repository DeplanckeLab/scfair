require "net/http"
require "json"
require "uri"

class ScpComplianceCheckImporter
  DEFAULT_BASE_URL = "https://asap.epfl.ch".freeze
  CATALOG_SOURCE = "broad_scp".freeze
  DOWNLOAD_URL_RE = %r{https://singlecell\.broadinstitute\.org/single_cell/api/v1/site/studies/(SCP\d+)/download\?filename=[^"\s<>]+}i
  SCP_ID_RE = /(SCP\d+)/i

  attr_reader :base_url, :dry_run, :limit, :imported_checks, :updated_checks, :created_files, :updated_files, :missing_datasets, :errors

  def initialize(base_url: ENV.fetch("ASAP_BASE_URL", DEFAULT_BASE_URL), dry_run: ENV["DRY_RUN"] == "1", limit: ENV["LIMIT"]&.to_i)
    @base_url = base_url.to_s.chomp("/")
    @dry_run = dry_run
    @limit = limit
    @imported_checks = 0
    @updated_checks = 0
    @created_files = 0
    @updated_files = 0
    @missing_datasets = 0
    @errors = []
  end

  def perform
    downloads = catalog_downloads
    downloads = downloads.first(limit) if limit&.positive?
    puts "Found #{downloads.size} Broad SCP download URLs in ASAP catalog (dry_run=#{dry_run})"

    downloads.each_with_index do |entry, index|
      process_download(entry)
      if ((index + 1) % 50).zero?
        puts "progress #{index + 1}/#{downloads.size} files_created=#{created_files} checks_imported=#{imported_checks} checks_updated=#{updated_checks} missing_datasets=#{missing_datasets} errors=#{errors.size}"
      end
    end

    summary
    errors.empty?
  end

  private

  def catalog_downloads
    by_url = {}

    each_catalog_candidate_id do |candidate_id|
      html = fetch_html("#{@base_url}/external_catalog_candidates/#{candidate_id}")
      URI.extract(html, %w[http https]).each do |raw_url|
        url = raw_url.rstrip.sub(/[.,);]+$/, "")
        next unless url.match?(DOWNLOAD_URL_RE)

        scp_id = url[SCP_ID_RE, 1]&.upcase
        next if scp_id.blank?

        filename = filename_from_url(url)
        filetype = filetype_from_filename(filename)
        by_url[url] = {
          scp_id: scp_id,
          url: url,
          filename: filename,
          filetype: filetype
        }
      end
    end

    by_url.values.sort_by { |entry| entry[:scp_id] }
  end

  def each_catalog_candidate_id
    seen = {}
    page = 1

    loop do
      html = fetch_html("#{@base_url}/external_catalog_candidates?source=#{CATALOG_SOURCE}&page=#{page}")
      ids = html.scan(%r{/external_catalog_candidates/(\d+)}).flatten.map(&:to_i).uniq
      break if ids.empty?

      new_ids = ids.reject { |id| seen[id] }
      break if page > 1 && new_ids.empty?

      new_ids.each do |id|
        seen[id] = true
        yield id
      end

      page += 1
      break if page > 200
    end
  end

  def process_download(entry)
    payload = lookup_compliance(entry[:url])
    dataset = Dataset.joins(:source).find_by(sources: { slug: "scp" }, source_reference_id: entry[:scp_id])

    if dataset.nil?
      @missing_datasets += 1
      if payload
        upsert_check(payload, file_resource: nil)
      end
      return
    end

    file_resource = nil
    if entry[:filetype].present? && FileResource::VALID_FILETYPES.include?(entry[:filetype])
      file_resource = upsert_file_resource(dataset, entry)
    end

    upsert_check(payload, file_resource: file_resource) if payload
  rescue => e
    @errors << "#{entry[:url]}: #{e.message}"
  end

  def upsert_file_resource(dataset, entry)
    resource = dataset.file_resources.find_or_initialize_by(url: entry[:url])
    was_new = resource.new_record?
    resource.filetype = entry[:filetype]
    resource.title = entry[:filename].presence
    return resource if dry_run

    resource.save!
    if was_new
      @created_files += 1
    else
      @updated_files += 1
    end
    resource
  end

  def upsert_check(payload, file_resource:)
    attrs = {
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

    if dry_run
      @imported_checks += 1
      return attrs
    end

    record = ComplianceCheck.find_or_initialize_by(asap_id: attrs[:asap_id])
    was_new = record.new_record?
    # Keep an existing file_resource link if this run has none.
    attrs.delete(:file_resource_id) if attrs[:file_resource_id].nil? && record.file_resource_id.present?
    record.assign_attributes(attrs)
    record.save!

    if record.file_resource_id.present?
      ComplianceCheck
        .where(file_resource_id: record.file_resource_id)
        .where.not(id: record.id)
        .update_all(file_resource_id: nil, updated_at: Time.current)
    end

    if was_new
      @imported_checks += 1
    else
      @updated_checks += 1
    end
    record
  end

  def lookup_compliance(source_url)
    variants_for(source_url).each do |variant|
      payload = lookup(variant)
      return payload if payload
    end
    nil
  end

  def variants_for(source_url)
    uri = URI.parse(source_url)
    params = URI.decode_www_form(uri.query.to_s).to_h
    filename = params["filename"]
    return [source_url] if filename.blank?

    [
      source_url,
      "#{uri.scheme}://#{uri.host}#{uri.path}?filename=#{URI.encode_www_form_component(filename)}",
      "#{uri.scheme}://#{uri.host}#{uri.path}?filename=#{filename.gsub('/', '%2F')}"
    ].uniq
  rescue URI::InvalidURIError
    [source_url]
  end

  def lookup(source_url)
    uri = URI("#{@base_url}/compliance/checks")
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

  def filename_from_url(url)
    uri = URI.parse(url)
    URI.decode_www_form(uri.query.to_s).to_h["filename"].to_s
  rescue URI::InvalidURIError
    ""
  end

  def filetype_from_filename(filename)
    name = filename.to_s.downcase
    return "tsv.gz" if name.end_with?(".tsv.gz")
    return "h5ad" if name.end_with?(".h5ad")
    return "rds" if name.end_with?(".rds") || name.end_with?(".rdata")

    nil
  end

  def fetch_html(url)
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 30, read_timeout: 60) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end
    raise "HTTP #{response.code} for #{url}" unless response.code.to_i == 200

    response.body.to_s
  end

  def summary
    puts "Done. created_files=#{created_files} updated_files=#{updated_files} imported_checks=#{imported_checks} updated_checks=#{updated_checks} missing_datasets=#{missing_datasets} errors=#{errors.size}"
    errors.first(20).each { |message| puts "  error: #{message}" }
  end
end
