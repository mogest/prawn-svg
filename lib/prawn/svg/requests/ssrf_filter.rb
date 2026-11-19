module Prawn::SVG::Requests
  class SsrfFilter < Http
    def initialize(max_response_bytes: DEFAULT_MAX_RESPONSE_BYTES, total_timeout: DEFAULT_TOTAL_TIMEOUT, **ssrf_filter_options)
      super(max_response_bytes: max_response_bytes, total_timeout: total_timeout)
      @ssrf_filter_options = ssrf_filter_options
    end

    private

    def get(uri, &block)
      ::SsrfFilter.get(uri, @ssrf_filter_options, &block)
    rescue ::SsrfFilter::PrivateIPAddress => e
      raise Prawn::SVG::Requests::Error, "refused potentially unsafe request: #{e.message}"
    end
  end
end
