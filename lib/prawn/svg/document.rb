require 'stringio'

class Prawn::SVG::Document
  Error = Class.new(Prawn::SVG::Error)
  InvalidSVGData = Class.new(Error)
  WorkLimitExceeded = Class.new(Error)

  DEFAULT_FALLBACK_FONT_NAME = 'Times-Roman'.freeze
  DEFAULT_MAX_WORK = 1_000_000
  MAX_ELEMENT_DEPTH = 200
  MAX_ENTITY_EXPANSION_BYTES = 10_000_000

  # An +Array+ of Prawn::SVG::Issue objects describing problems that occurred while parsing/rendering the SVG data.
  attr_reader :issues

  attr_reader :root,
    :sizing,
    :fallback_font_name,
    :font_registry,
    :url_loader,
    :resource_loader,
    :work_budget,
    :elements_by_id, :gradients,
    :element_styles,
    :color_mode,
    :external_svg_cache,
    :image_dimensions,
    :root_document

  def initialize(data, bounds, options, font_registry: nil, css_parser: CssParser::Parser.new, attribute_overrides: {}, root_document: nil)
    @root_document = root_document || self
    @font_registry = font_registry

    begin
      data = data.encode(Encoding::UTF_8) if data.is_a?(String) && data.encoding.name.start_with?('UTF-16', 'UTF-32')
      @root = parse_root(data) or raise_parse_error(data)
    rescue RuntimeError, EncodingError => e
      raise_parse_error(data, e.message)
    end

    @issues = []
    @issue_set = Set.new
    @options = options
    @work_budget = root_document ? root_document.work_budget : Prawn::SVG::WorkBudget.new(load_max_work)
    @elements_by_id = {}
    @gradients = Prawn::SVG::Gradients.new(self)
    @external_svg_cache = {}
    @image_dimensions = {}
    @fallback_font_name = options.fetch(:fallback_font_name, DEFAULT_FALLBACK_FONT_NAME)
    @color_mode = load_color_mode

    @url_loader = Prawn::SVG::UrlLoader.new(
      cache:         options.fetch(:cache_requests) { options.fetch(:cache_images, true) && {} },
      web_requests:  options.fetch(:web_requests) { options[:enable_web_requests] },
      file_requests: options.fetch(:file_requests) { options[:enable_file_requests_with_root] }
    )
    @resource_loader =
      root_document ? root_document.resource_loader.with_url_loader(url_loader) : Prawn::SVG::ResourceLoader.new(url_loader, work_budget)

    attributes = @root.attributes.dup
    attribute_overrides.each { |key, value| attributes.add(REXML::Attribute.new(key, value)) }

    @sizing = Prawn::SVG::Calculators::DocumentSizing.new(bounds, attributes)
    calculate_sizing(requested_width: options[:width], requested_height: options[:height])

    stylesheets = Prawn::SVG::CSS::Stylesheets.new(css_parser, root, resource_loader: resource_loader, work_budget: work_budget)
    @element_styles = stylesheets.load
    stylesheets.issues.each { |issue| add_issue(issue.category, issue.message) }
    process_font_face_rules(stylesheets.font_face_rules)

    yield self if block_given?
  end

  # REXML expands entities lazily, raising a RuntimeError if they grow too large, so expand them all now where the
  # error can be handled.  REXML::ParseException is also a RuntimeError.
  # REXML's own limits still allow each of thousands of references to expand to 10KB, so also cap how much the text
  # of every document parsed in the render may grow beyond the size of its data.
  def parse_root(data)
    return root_document.parse_root(data) unless root_document.equal?(self)

    root = REXML::Document.new(data).root
    return unless root

    @expansion_bytes_remaining ||= MAX_ENTITY_EXPANSION_BYTES
    bytes_remaining = (data.is_a?(String) ? data.bytesize : 0) + @expansion_bytes_remaining
    expand = lambda do |value|
      bytes_remaining -= value.bytesize
      raise 'entities expand to too much text' if bytes_remaining.negative?
    end
    text = +''

    stack = [[root, 1]]
    while (element, depth = stack.pop)
      raise 'elements are nested too deeply' if depth > MAX_ELEMENT_DEPTH

      element.attributes.each_attribute { |attribute| expand.call(attribute.value) }
      element.children.each do |child|
        case child
        when REXML::Element then stack << [child, depth + 1]
        when REXML::Text
          expand.call(child.value)
          text << child.value
        end
      end
    end
    @expansion_bytes_remaining = [@expansion_bytes_remaining, bytes_remaining].min
    font_registry&.add_text(text)
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
    work_budget.record(250)
    self.class.new(
      data, [width, height],
      # Without the root's cache, it can't read files the root cached.  Its web URLs still go through the root.
      @options.merge(file_requests: false, cache_requests: false, width: width, height: height),
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

    font_data = StringIO.new(resource_loader.load(url))
    raise Prawn::SVG::Requests::Error, 'font data could not be parsed' unless font_registry.usable?(font_data)

    font_registry.register_font_face(family, weight, style, stretch, font_data)
    true
  rescue Prawn::SVG::Requests::Error => e
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

    if data.is_a?(String) && data.b.end_with?('.svg')
      message += "  It looks like you've supplied a filename instead; use File.read(filename) to get the data from the file before you pass it to prawn-svg."
    end

    message += "\n#{exception_message}" if exception_message

    raise InvalidSVGData, message
  end
end
