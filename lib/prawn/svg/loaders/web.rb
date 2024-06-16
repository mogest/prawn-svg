require 'net/http'

module Prawn::SVG::Loaders
  class Web
    def from_url(url)
      uri = build_uri(url)

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
