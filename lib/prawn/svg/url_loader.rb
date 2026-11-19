class Prawn::SVG::UrlLoader
  Error = Prawn::SVG::Requests::Error

  # Content fetched from the web may only refer to other web or data URLs, resolved against its own URL, so it can
  # never reach the local filesystem.  Returns nil for any other reference.
  def self.resolve_remote_reference(base_url, reference)
    return reference if reference.match?(/\Adata:/i)

    url = URI.join(base_url, reference.strip)
    url.to_s if url.is_a?(URI::HTTP)
  rescue URI::Error
  end

  def self.web_url?(url)
    url.to_s.match?(/\Ahttps?:/i)
  end

  attr_reader :enable_cache, :loaders

  def initialize(enable_cache: false, web_requests: false, file_requests: false)
    @url_cache = {}
    @enable_cache = enable_cache

    @loaders = []
    loaders << Prawn::SVG::Loaders::Data.new
    loaders << Prawn::SVG::Loaders::Web.new(web_requests)
    loaders << Prawn::SVG::Loaders::File.new(file_requests)
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
    try_each_loader(url) or raise Error, 'No handler available for this URL scheme'
  end

  def try_each_loader(url)
    loaders.detect do |loader|
      data = loader.from_url(url)
      break data if data
    end
  end
end
