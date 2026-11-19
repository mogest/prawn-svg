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

    DEFAULT_MAX_RESPONSE_BYTES = 20_000_000
    DEFAULT_TOTAL_TIMEOUT = 30

    def initialize(max_response_bytes: DEFAULT_MAX_RESPONSE_BYTES, total_timeout: DEFAULT_TOTAL_TIMEOUT)
      @max_response_bytes = max_response_bytes
      @total_timeout = total_timeout
    end

    # The body is read in chunks, after any decompression, so that neither a large nor a highly compressed response
    # can be held in memory in full.
    def call(uri)
      body = nil
      response = Timeout.timeout(@total_timeout) do
        get(uri) do |chunked_response|
          body = ''.b
          chunked_response.read_body do |chunk|
            body << chunk
            raise Prawn::SVG::UrlLoader::Error, "response is larger than #{@max_response_bytes} bytes" if body.bytesize > @max_response_bytes
          end
        end
      end

      raise Prawn::SVG::UrlLoader::Error, "request failed with status #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

      body.to_s
    rescue Timeout::Error
      raise Prawn::SVG::UrlLoader::Error, 'request timed out'
    rescue *EXPECTED_ERRORS => e
      raise Prawn::SVG::UrlLoader::Error, e.message
    end
  end
end
