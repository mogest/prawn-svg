module Prawn::SVG::Loaders
  class Web
    def initialize(web_requests)
      raise ArgumentError, ':web_requests must be true, false or a callable' unless [true, false, nil].include?(web_requests) || web_requests.respond_to?(:call)

      @request_fn = web_requests == true ? Prawn::SVG::Requests::SsrfFilter.new : web_requests
    end

    def from_url(url)
      uri = build_uri(url)
      return unless uri.is_a?(URI::HTTP)

      raise Prawn::SVG::Requests::Error, 'web requests are disabled; see the :web_requests option' unless @request_fn
      raise Prawn::SVG::Requests::Error, 'web URL has no host' if uri.host.to_s.empty?

      perform_request(uri)
    end

    private

    def build_uri(url)
      URI(url)
    rescue URI::Error
    end

    def perform_request(uri)
      body = @request_fn.call(uri)
      raise TypeError, "web request returned #{body.class} instead of a String" unless body.is_a?(String)

      body
    end
  end
end
