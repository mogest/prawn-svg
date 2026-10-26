require 'tempfile'

class Prawn::SVG::Document
  Error = Class.new(StandardError)
  InvalidSVGData = Class.new(Error)

  DEFAULT_FALLBACK_FONT_NAME = 'Times-Roman'.freeze
  MAX_NESTED_DOCUMENTS = 50
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

  attr_accessor :nested_document_count, :use_count, :duplicated_value_count

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
    @nested_document_count = 0
    @use_count = 0
    @duplicated_value_count = 0
    @elements_by_id = {}
    @gradients = Prawn::SVG::Gradients.new(self)
    @external_svg_cache = {}
    @image_dimensions = {}
    @fallback_font_name = options.fetch(:fallback_font_name, DEFAULT_FALLBACK_FONT_NAME)
    @font_registry = font_registry
    @color_mode = load_color_mode
    @font_face_tempfiles = []

    @url_loader = Prawn::SVG::UrlLoader.new(
      enable_cache:          options[:cache_images],
      web_requests:          options.fetch(:web_requests) { options[:enable_web_requests] },
      enable_file_with_root: options[:enable_file_requests_with_root]
    )

    attributes = @root.attributes.dup
    attribute_overrides.each { |key, value| attributes.add(REXML::Attribute.new(key, value)) }

    @sizing = Prawn::SVG::Calculators::DocumentSizing.new(bounds, attributes)
    calculate_sizing(requested_width: options[:width], requested_height: options[:height])

    stylesheets = Prawn::SVG::CSS::Stylesheets.new(css_parser, root, url_loader: url_loader)
    @element_styles = stylesheets.load
    stylesheets.issues.each { |issue| add_issue(issue.category, issue.message) }
    process_font_face_rules(stylesheets.font_face_rules)

    yield self if block_given?
  end

  # SVG documents referenced by <image> and <use> can reference further documents, so limit how many a render loads.
  def reserve_nested_document
    return false if root_document.nested_document_count >= MAX_NESTED_DOCUMENTS

    root_document.nested_document_count += 1
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
      element.texts.each(&:value)
      element.elements.each { |child| stack << [child, depth + 1] }
    end
    root
  end

  def find_raw_element_by_id(id)
    @raw_elements_by_id ||= REXML::XPath.match(root, '//*[@id]').reverse.to_h { |element| [element.attributes['id'], element] }
    @raw_elements_by_id[id]
  end

  def add_issue(category, message)
    issue = Prawn::SVG::Issue.new(category, message)
    issues << issue if @issue_set.add?(issue)
  end

  # Retained for backwards compatibility; use #issues instead.
  def warnings
    issues.map(&:message).freeze
  end

  def replicate(data, width, height, attribute_overrides: {})
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

    data = url_loader.load(url)
    tempfile = Tempfile.new(['prawn-svg-font', '.ttf'])
    tempfile.binmode
    tempfile.write(data)
    tempfile.close
    @font_face_tempfiles << tempfile
    assert_usable_font(tempfile.path)

    font_registry.register_font_face(family, weight, style, stretch, tempfile.path)
    true
  rescue Prawn::SVG::UrlLoader::Error => e
    add_issue(:resource, "Failed to load @font-face font from #{source[:url]}: #{e.message}")
    false
  end

  def assert_usable_font(path)
    pdf = Prawn::Document.new
    pdf.font(path) { pdf.text 'a' }
    pdf.render
  rescue StandardError
    # Prawn's font parser raises arbitrary errors on corrupt data, which may have come from anywhere.
    raise Prawn::SVG::UrlLoader::Error, 'font data could not be parsed'
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
