module Prawn::SVG::Loaders
  class SsrfFilterRequest < HttpRequest
    def initialize(**ssrf_filter_options)
      super()
      @ssrf_filter_options = ssrf_filter_options
    end

    private

    def get(uri)
      SsrfFilter.get(uri, @ssrf_filter_options)
    rescue SsrfFilter::PrivateIPAddress => e
      raise Prawn::SVG::UrlLoader::Error, "refused potentially unsafe request: #{e.message}"
    end
  end
end
