require 'net/http'

module Prawn::SVG::Loaders
  class Web
    attr_reader :allowed_web_url_fn

    def initialize(allowed_web_url_fn)
      @allowed_web_url_fn = allowed_web_url_fn
    end

    def from_url(url, binary:) # rubocop:disable Lint/UnusedMethodArgument
      uri = build_uri(url)

      unless allowed_web_url_fn.call(uri)
        raise Prawn::SVG::UrlLoader::Error,
          'web URL does not pass validation of :enable_web_requests or :allowed_web_url_fn'
      end

      perform_request(uri) if uri && %w[http https].include?(uri.scheme)
    end

    private

    def build_uri(url)
      URI(url)
    rescue URI::InvalidURIError
    end

    def perform_request(uri)
      Net::HTTP.get(uri)
    rescue StandardError => e
      raise Prawn::SVG::UrlLoader::Error, e.message
    end
  end
end
