require 'tempfile'

class Prawn::SVG::Document
  class Error < StandardError
  end

  class InvalidSVGData < Error
  end

  DEFAULT_FALLBACK_FONT_NAME = 'Times-Roman'.freeze

  # An +Array+ of warnings that occurred while parsing the SVG data.
  attr_reader :warnings

  attr_reader :root,
    :sizing,
    :fallback_font_name,
    :font_registry,
    :url_loader,
    :elements_by_id, :gradients,
    :element_styles,
    :color_mode,
    :external_svg_cache

  def initialize(data, bounds, options, font_registry: nil, css_parser: CssParser::Parser.new,
                 attribute_overrides: {}, url_loader: nil)
    begin
      @root = REXML::Document.new(data).root or raise_parse_error(data)
    rescue REXML::ParseException => e
      raise_parse_error(data, e.message)
    end

    @warnings = []
    @options = options
    @elements_by_id = {}
    @gradients = Prawn::SVG::Gradients.new(self)
    @external_svg_cache = {}
    @fallback_font_name = options.fetch(:fallback_font_name, DEFAULT_FALLBACK_FONT_NAME)
    @font_registry = font_registry
    @color_mode = load_color_mode
    @font_face_tempfiles = []

    @url_loader = url_loader || Prawn::SVG::UrlLoader.new(
      # :cache_images is deprecated but still accepted for backwards compatibility
      enable_cache:          options[:cache_requests] || options[:cache_images],
      enable_web:            options[:enable_web_requests],
      enable_file_with_root: options[:enable_file_requests_with_root],
      cache_fn:              options[:cache_fn],
      allowed_web_url_fn:    options[:allowed_web_url_fn],
      allowed_file_path_fn:  options[:allowed_file_path_fn]
    )

    attributes = @root.attributes.dup
    attribute_overrides.each { |key, value| attributes.add(REXML::Attribute.new(key, value)) }

    @sizing = Prawn::SVG::Calculators::DocumentSizing.new(bounds, attributes)
    calculate_sizing(requested_width: options[:width], requested_height: options[:height])

    stylesheets = Prawn::SVG::CSS::Stylesheets.new(css_parser, root, url_loader: @url_loader, warnings: warnings)
    @element_styles = stylesheets.load
    process_font_face_rules(stylesheets.font_face_rules)

    yield self if block_given?
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

  def new_subdocument(data, width, height, attribute_overrides)
    new(data, [width, height], { width: width, height: height },
      font_registry:       font_registry,
      css_parser:          css_parser,
      attribute_overrides: attribute_overrides,
      url_loader:          url_loader)
  end

  private

  def process_font_face_rules(rules)
    return unless font_registry

    rules.each do |declarations|
      decl_hash = {}
      declarations.each { |name, value, _| decl_hash[name] = value }

      family = unquote_css_string(decl_hash['font-family'])
      next unless family

      src = decl_hash['src']
      next unless src

      weight = decl_hash['font-weight']
      style = decl_hash['font-style']
      stretch = decl_hash['font-stretch']

      load_font_face_source(family, weight, style, stretch, src)
    end
  end

  def load_font_face_source(family, weight, style, stretch, src)
    sources = Prawn::SVG::CSS::FontFaceParser.parse_src(src)

    sources.detect do |source|
      case source[:type]
      when :local
        load_local_font_face(family, weight, style, stretch, source[:name])
      when :url
        load_url_font_face(family, weight, style, stretch, source)
      end
    end
  end

  def load_local_font_face(family, weight, style, stretch, local_name)
    font_data = font_registry.find_local_font_data(local_name, weight, style, stretch)
    return unless font_data

    font_registry.register_font_face(family, weight, style, stretch, font_data)
    true
  end

  def load_url_font_face(family, weight, style, stretch, source)
    return if source[:format] && !Prawn::SVG::CSS::FontFaceParser::SUPPORTED_FORMATS.include?(source[:format])

    data = url_loader.load(source[:url], binary: true)
    tempfile = Tempfile.new(['prawn-svg-font', '.ttf'])
    tempfile.binmode
    tempfile.write(data)
    tempfile.close
    @font_face_tempfiles << tempfile

    font_registry.register_font_face(family, weight, style, stretch, tempfile.path)
    true
  rescue Prawn::SVG::UrlLoader::Error => e
    warnings << "Failed to load @font-face font from #{source[:url]}: #{e.message}"
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
