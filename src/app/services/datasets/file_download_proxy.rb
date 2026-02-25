require "net/http"
require "openssl"
require "uri"

module Datasets
  class FileDownloadProxy
    Result = Struct.new(:success?, :http_status, :body, :filename, :content_type, keyword_init: true)

    REDIRECT_LIMIT = 5
    DEFAULT_CONTENT_TYPE = "application/octet-stream"
    USER_AGENT = "Mozilla/5.0 (compatible; scFAIR downloader)"

    def initialize(resource:)
      @resource = resource
    end

    def call
      uri = URI.parse(@resource.url.to_s)
      return failure(:bad_request) unless uri.is_a?(URI::HTTP)

      remote_response = fetch_remote_response(uri)
      return failure(:bad_gateway) unless remote_response.is_a?(Net::HTTPSuccess)

      success(remote_response, uri)
    rescue URI::InvalidURIError
      failure(:bad_request)
    rescue OpenSSL::SSL::SSLError, Timeout::Error, SystemCallError
      failure(:bad_gateway)
    end

    private
      def success(remote_response, uri)
        Result.new(
          success?: true,
          body: remote_response.body,
          filename: safe_filename(uri),
          content_type: remote_response["content-type"].presence || DEFAULT_CONTENT_TYPE
        )
      end

      def safe_filename(uri)
        filename = @resource.title.presence || File.basename(uri.path).presence || "dataset.#{@resource.filetype}"
        filename.to_s.tr("\"", "'")
      end

      def fetch_remote_response(uri, redirects_left = REDIRECT_LIMIT)
        raise URI::InvalidURIError, "Too many redirects" if redirects_left <= 0

        response = response_with_ssl_fallback(uri)
        return response unless response.is_a?(Net::HTTPRedirection)

        next_uri = resolve_redirect_uri(response, uri)
        fetch_remote_response(next_uri, redirects_left - 1)
      end

      def response_with_ssl_fallback(uri)
        http_get_response(uri, verify_ssl: true)
      rescue OpenSSL::SSL::SSLError
        http_get_response(uri, verify_ssl: false)
      end

      def resolve_redirect_uri(response, current_uri)
        next_location = response["location"]
        raise URI::InvalidURIError, "Missing redirect location" if next_location.blank?

        redirected_uri = URI.parse(next_location)
        redirected_uri.relative? ? current_uri + next_location : redirected_uri
      end

      def http_get_response(uri, verify_ssl:)
        options = ssl_options(uri, verify_ssl: verify_ssl)

        Net::HTTP.start(uri.host, uri.port, **options) do |http|
          request = Net::HTTP::Get.new(uri.request_uri)
          request["User-Agent"] = USER_AGENT
          request["Accept"] = "*/*"
          request["Referer"] = "#{uri.scheme}://#{uri.host}/"
          http.request(request)
        end
      end

      def ssl_options(uri, verify_ssl:)
        return { use_ssl: false } unless uri.scheme == "https"

        if verify_ssl
          store = OpenSSL::X509::Store.new
          store.set_default_paths
          { use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_PEER, cert_store: store }
        else
          { use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE }
        end
      end

      def failure(status)
        Result.new(success?: false, http_status: status)
      end
  end
end
