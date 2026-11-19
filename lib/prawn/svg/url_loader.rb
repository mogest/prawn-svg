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

  attr_reader :cache, :loaders

  def initialize(cache: {}, web_requests: false, file_requests: false)
    raise ArgumentError, ':cache_requests must be false, nil or respond to [] and []=' if cache && !hash_like?(cache)

    @cache = cache
    @failures = {}

    @loaders = []
    loaders << Prawn::SVG::Loaders::Data.new
    loaders << Prawn::SVG::Loaders::Web.new(web_requests)
    loaders << Prawn::SVG::Loaders::File.new(file_requests)
  end

  def load(url)
    return perform(url) if !cache || url.match?(/\Adata:/i)

    cache[url] ||= perform_once(url)
  end

  private

  def hash_like?(object)
    object.respond_to?(:[]) && object.respond_to?(:[]=)
  end

  def perform_once(url)
    raise @failures[url] if @failures.key?(url)

    perform(url)
  rescue Error => e
    raise @failures[url] = e
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
