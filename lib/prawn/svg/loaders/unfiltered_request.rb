module Prawn::SVG::Loaders
  class UnfilteredRequest < HttpRequest
    def initialize(max_redirects: 10, **http_options)
      super()
      @max_redirects = max_redirects
      @http_options = http_options
    end

    private

    def get(uri)
      (@max_redirects + 1).times do
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', **@http_options) do |http|
          http.request(Net::HTTP::Get.new(uri))
        end
        return response unless response.is_a?(Net::HTTPRedirection) && response['location']

        uri = uri.merge(response['location'])
        raise Prawn::SVG::UrlLoader::Error, "redirected to unsupported URL #{uri}" unless uri.is_a?(URI::HTTP) && !uri.host.to_s.empty?
      end

      raise Prawn::SVG::UrlLoader::Error, 'too many redirects'
    end
  end
end
