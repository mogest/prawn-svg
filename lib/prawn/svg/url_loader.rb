require 'open-uri'
require 'base64'

class Prawn::SVG::UrlLoader
  attr_accessor :enable_cache, :enable_web
  attr_reader :url_cache

  DATAURL_REGEXP = /(data:image\/(png|jpg);base64(;[a-z0-9]+)*,)/
  URL_REGEXP = /^https?:\/\/|#{DATAURL_REGEXP}/

  def initialize(opts = {})
    @url_cache = {}
    @enable_cache = opts.fetch(:enable_cache, false)
    @enable_web = opts.fetch(:enable_web, true)
  end

  def valid?(url)
    !!url.match(URL_REGEXP)
  end

  def load(url)
    @url_cache[url] || begin
      if m = url.match(DATAURL_REGEXP)
        data = Base64.decode64(url[m[0].length .. -1])
      elsif enable_web
        data = open(url).read
      else
        raise "No handler available to retrieve URL #{url}"
      end
      @url_cache[url] = data if enable_cache
      data
    end
  end
end
