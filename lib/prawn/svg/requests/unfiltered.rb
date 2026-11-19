module Prawn::SVG::Requests
  class Unfiltered < Http
    def initialize(max_redirects: 10, max_response_bytes: DEFAULT_MAX_RESPONSE_BYTES, total_timeout: DEFAULT_TOTAL_TIMEOUT, **http_options)
      super(max_response_bytes: max_response_bytes, total_timeout: total_timeout)
      @max_redirects = max_redirects
      @http_options = http_options
    end

    private

    def get(uri, &block)
      (@max_redirects + 1).times do
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', **@http_options) do |http|
          http.request(Net::HTTP::Get.new(uri), &block)
        end
        return response unless response.is_a?(Net::HTTPRedirection) && response['location']

        uri = uri.merge(response['location'])
        raise Prawn::SVG::Requests::Error, "redirected to unsupported URL #{uri}" unless uri.is_a?(URI::HTTP) && !uri.host.to_s.empty?
      end

      raise Prawn::SVG::Requests::Error, 'too many redirects'
    end
  end
end
