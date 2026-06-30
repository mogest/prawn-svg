require 'net/http'
require 'openssl'
require 'ssrf_filter'
require 'zlib'

module Prawn::SVG::Loaders
  class HttpRequest
    EXPECTED_ERRORS = [
      SsrfFilter::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError, IOError, URI::Error,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, Zlib::Error
    ].freeze

    def call(uri)
      response = get(uri)

      raise Prawn::SVG::UrlLoader::Error, "request failed with status #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

      response.body.to_s
    rescue Timeout::Error
      raise Prawn::SVG::UrlLoader::Error, 'request timed out'
    rescue *EXPECTED_ERRORS => e
      raise Prawn::SVG::UrlLoader::Error, e.message
    end
  end
end
