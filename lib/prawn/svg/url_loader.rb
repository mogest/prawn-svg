class Prawn::SVG::UrlLoader
  class Error < StandardError
  end

  attr_reader :cache_fn, :allowed_web_url_fn, :file_fn, :loaders

  def initialize(enable_cache: nil, enable_web: nil, enable_file_with_root: nil, cache_fn: nil,
                 allowed_web_url_fn: nil, allowed_file_path_fn: nil)
    if !enable_cache.nil? && !cache_fn.nil?
      raise ArgumentError,
        'Only one of :cache_requests and :cache_fn may be supplied'
    end
    if !enable_web.nil? && !allowed_web_url_fn.nil?
      raise ArgumentError,
        'Only one of :enable_web_requests and :allowed_web_url_fn may be supplied'
    end
    if !enable_file_with_root.nil? && !allowed_file_path_fn.nil?
      raise ArgumentError,
        'Only one of :enable_file_requests_with_root and :allowed_file_path_fn may be supplied'
    end

    default_file_path_fn = parse_enable_file_with_root(enable_file_with_root)

    @cache_fn = cache_fn || ->(_) { enable_cache }
    @allowed_web_url_fn = allowed_web_url_fn || (enable_web && ->(_) { true }) || nil
    @allowed_file_path_fn = allowed_file_path_fn || default_file_path_fn || nil

    @url_cache = {}
    @loaders = []
    loaders << Prawn::SVG::Loaders::Data.new
    loaders << Prawn::SVG::Loaders::Web.new(allowed_web_url_fn) if allowed_web_url_fn
    loaders << Prawn::SVG::Loaders::File.new(allowed_file_path_fn) if allowed_file_path_fn
  end

  def load(url, binary: true)
    retrieve_from_cache(url) || perform_and_cache(url, binary: binary)
  end

  def add_to_cache(url, data)
    @url_cache[url] = data
  end

  def retrieve_from_cache(url)
    @url_cache[url]
  end

  private

  def perform_and_cache(url, binary:)
    data = perform(url, binary: binary)
    add_to_cache(url, data) if cache_fn.call(url)
    data
  end

  def perform(url, binary:)
    try_each_loader(url, binary: binary) or raise Error,
      'No handler available for this URL scheme.  Check :enable_web_requests, :enable_file_requests_with_root, ' \
      ':allowed_web_url_fn, and :allowed_file_path_fn options to allow web and file URLs to be loaded.'
  end

  def try_each_loader(url, binary:)
    loaders.detect do |loader|
      data = loader.from_url(url, binary: binary)
      break data if data
    end
  end

  def parse_enable_file_with_root(root_path)
    return nil if root_path.nil?

    if root_path.empty?
      raise ArgumentError,
        "An empty string is not a valid root path for :enable_file_requests_with_root.  Use '.' if you want the " \
        'current working directory.'
    end

    path = ::File.expand_path(root_path)

    raise ArgumentError, "#{root_path} specified in :enable_file_requests_with_root is not a directory" unless Dir.exist?(path)

    root_path = "#{path}#{::File::SEPARATOR}"

    # TODO : case sensitive comparison, but it's going to be a bit of a headache
    # making it dependent on whether the file system is case sensitive or not.
    # Leaving it like this until it's a problem for someone.
    ->(path) { path.start_with?(root_path) }
  end
end
