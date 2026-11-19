require 'stringio'

class Prawn::SVG::Document
  Error = Class.new(StandardError)
  InvalidSVGData = Class.new(Error)
  WorkLimitExceeded = Class.new(Error)

  DEFAULT_FALLBACK_FONT_NAME = 'Times-Roman'.freeze
  DEFAULT_MAX_WORK = 1_000_000
  MAX_ELEMENT_DEPTH = 200

  # An +Array+ of Prawn::SVG::Issue objects describing problems that occurred while parsing/rendering the SVG data.
  attr_reader :issues

  attr_reader :root,
    :sizing,
    :fallback_font_name,
    :font_registry,
    :url_loader,
    :elements_by_id, :gradients,
    :element_styles,
    :color_mode,
    :external_svg_cache,
    :image_dimensions,
    :root_document

  def initialize(data, bounds, options, font_registry: nil, css_parser: CssParser::Parser.new, attribute_overrides: {}, root_document: nil)
    begin
      @root = self.class.parse_root(data) or raise_parse_error(data)
    rescue RuntimeError => e
      raise_parse_error(data, e.message)
    end

    @issues = []
    @issue_set = Set.new
    @options = options
    @root_document = root_document || self
    @max_work = @work_remaining = load_max_work unless root_document
    @elements_by_id = {}
    @gradients = Prawn::SVG::Gradients.new(self)
    @external_svg_cache = {}
    @image_dimensions = {}
    @fallback_font_name = options.fetch(:fallback_font_name, DEFAULT_FALLBACK_FONT_NAME)
    @font_registry = font_registry
    @color_mode = load_color_mode

    @url_loader = Prawn::SVG::UrlLoader.new(
      enable_cache:          options[:cache_images],
      web_requests:          options.fetch(:web_requests) { options[:enable_web_requests] },
      enable_file_with_root: options[:enable_file_requests_with_root]
    )

    attributes = @root.attributes.dup
    attribute_overrides.each { |key, value| attributes.add(REXML::Attribute.new(key, value)) }

    @sizing = Prawn::SVG::Calculators::DocumentSizing.new(bounds, attributes)
    calculate_sizing(requested_width: options[:width], requested_height: options[:height])

    stylesheets = Prawn::SVG::CSS::Stylesheets.new(css_parser, root, url_loader: url_loader, record_work: method(:record_work))
    @element_styles = stylesheets.load
    stylesheets.issues.each { |issue| add_issue(issue.category, issue.message) }
    process_font_face_rules(stylesheets.font_face_rules)

    yield self if block_given?
  end

  # Bounds the time and memory a render can take, so small hostile input can't run away with either.  A unit is
  # roughly an element, a drawing call recorded or copied, a character of text, a few hundred bytes of loaded data or
  # 25 elements checked against a simple CSS selector.
  # The budget is shared by the whole render, including nested documents.
  def record_work(units)
    return root_document.record_work(units) unless root_document.equal?(self)
    return unless @work_remaining

    raise WorkLimitExceeded, 'The SVG needs too much work to render; see the :max_work option' if (@work_remaining -= units).negative?
  end

  # Requests for non-data URLs are charged whether or not they succeed, so fan-out can't make endless requests.
  def load_url(url)
    record_work(1000) unless url.match?(/\Adata:/i)
    url_loader.load(url).tap { |data| record_work(data.bytesize / 256) }
  end

  def reset_work_budget
    @work_remaining = @max_work
  end

  # REXML expands entities lazily, raising a RuntimeError if they grow too large, so expand them all now where the
  # error can be handled.  REXML::ParseException is also a RuntimeError.
  def self.parse_root(data)
    root = REXML::Document.new(data).root
    return unless root

    stack = [[root, 1]]
    while (element, depth = stack.pop)
      raise 'elements are nested too deeply' if depth > MAX_ELEMENT_DEPTH

      element.attributes.each_attribute(&:value)
      element.children.each do |child|
        case child
        when REXML::Element then stack << [child, depth + 1]
        when REXML::Text then child.value
        end
      end
    end
    root
  end

  def language
    @options[:language] || 'en'
  end

  def find_raw_element_by_id(id)
    # Walk the tree rather than use XPath, as REXML sorts XPath results in time proportional to matches x siblings.
    @raw_elements_by_id ||= {}.tap do |index|
      stack = [root]
      while (element = stack.pop)
        element_id = element.attributes['id']
        index[element_id] ||= element if element_id
        stack.concat(element.children.grep(REXML::Element).reverse)
      end
    end
    @raw_elements_by_id[id]
  end

  def add_issue(category, message)
    return root_document.add_issue(category, message) unless root_document.equal?(self)

    issue = Prawn::SVG::Issue.new(category, message)
    issues << issue if @issue_set.add?(issue)
  end

  # Retained for backwards compatibility; use #issues instead.
  def warnings
    issues.map(&:message).freeze
  end

  def replicate(data, width, height, attribute_overrides: {})
    # A nested document holds far more memory than its few elements are charged for.
    record_work(250)
    options = @options.reject { |key, _| key == :enable_file_requests_with_root }

    self.class.new(
      data, [width, height],
      options.merge(width: width, height: height),
      font_registry:       font_registry&.fork,
      attribute_overrides: attribute_overrides,
      root_document:       root_document
    )
  end

  def calculate_sizing(requested_width: nil, requested_height: nil)
    sizing.requested_width = requested_width
    sizing.requested_height = requested_height
    sizing.calculate
  end

  def with_sizing(temporary_sizing)
    original = @sizing
    @sizing = temporary_sizing
    yield
  ensure
    @sizing = original
  end

  private

  def process_font_face_rules(rules)
    return unless font_registry

    rules.each do |declarations, base_url|
      decl_hash = {}
      declarations.each { |name, value, _| decl_hash[name] = value }

      family = unquote_css_string(decl_hash['font-family'])
      next unless family

      src = decl_hash['src']
      next unless src

      weight = decl_hash['font-weight']
      style = decl_hash['font-style']
      stretch = decl_hash['font-stretch']

      load_font_face_source(family, weight, style, stretch, src, base_url)
    end
  end

  def load_font_face_source(family, weight, style, stretch, src, base_url)
    sources = Prawn::SVG::CSS::FontFaceParser.parse_src(src)

    sources.detect do |source|
      case source[:type]
      when :local
        load_local_font_face(family, weight, style, stretch, source[:name])
      when :url
        load_url_font_face(family, weight, style, stretch, source, base_url)
      end
    end
  end

  def load_local_font_face(family, weight, style, stretch, local_name)
    font_data = font_registry.find_local_font_data(local_name, weight, style, stretch)
    return unless font_data

    font_registry.register_font_face(family, weight, style, stretch, font_data)
    true
  end

  def load_url_font_face(family, weight, style, stretch, source, base_url)
    return if source[:format] && !Prawn::SVG::CSS::FontFaceParser::SUPPORTED_FORMATS.include?(source[:format])

    url = base_url ? Prawn::SVG::UrlLoader.resolve_remote_reference(base_url, source[:url]) : source[:url]
    unless url
      add_issue(:resource, "stylesheet from '#{base_url}' may not reference '#{source[:url]}'")
      return false
    end

    font_data = url_loader.load(url)
    raise Prawn::SVG::UrlLoader::Error, 'font data could not be parsed' unless font_registry.usable_font_face_data?(font_data)

    font_registry.register_font_face(family, weight, style, stretch, StringIO.new(font_data))
    true
  rescue Prawn::SVG::UrlLoader::Error => e
    add_issue(:resource, "Failed to load @font-face font from #{source[:url]}: #{e.message}")
    false
  end

  def unquote_css_string(value)
    return unless value

    value = value.strip
    if (value.start_with?('"') && value.end_with?('"')) || (value.start_with?("'") && value.end_with?("'"))
      value[1..-2]
    else
      value
    end
  end

  def load_max_work
    max_work = @options.fetch(:max_work, DEFAULT_MAX_WORK)
    return max_work if max_work == false || (max_work.is_a?(Integer) && max_work.positive?)

    raise ArgumentError, ':max_work must be a positive integer or false'
  end

  def load_color_mode
    case @options[:color_mode]
    when nil, :rgb then :rgb
    when :cmyk then :cmyk
    else
      raise ArgumentError, ':color_mode must be set to :rgb (default) or :cmyk'
    end
  end

  def raise_parse_error(data, exception_message = nil)
    message = 'The data supplied is not a valid SVG document.'

    if data.respond_to?(:end_with?) && data.end_with?('.svg')
      message += "  It looks like you've supplied a filename instead; use File.read(filename) to get the data from the file before you pass it to prawn-svg."
    end

    message += "\n#{exception_message}" if exception_message

    raise InvalidSVGData, message
  end
end
