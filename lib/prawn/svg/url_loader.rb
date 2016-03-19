class Prawn::SVG::UrlLoader
  Error = Class.new(StandardError)

  attr_reader :enable_cache, :enable_web

  def initialize(enable_cache: false, enable_web: true)
    @url_cache = {}
    @enable_cache = enable_cache
    @enable_web = enable_web
  end

  def load(url)
    retrieve_from_cache(url) || perform_and_cache(url)
  end

  def add_to_cache(url, data)
    @url_cache[url] = data
  end

  def retrieve_from_cache(url)
    @url_cache[url]
  end

  private

  def perform_and_cache(url)
    data = perform(url)
    add_to_cache(url, data) if enable_cache
    data
  end

  def perform(url)
    Prawn::SVG::Loaders::Data.from_url(url) or
      enable_web && Prawn::SVG::Loaders::Web.from_url(url) or
      raise Error, "No handler available for this URL scheme"
  end
end
