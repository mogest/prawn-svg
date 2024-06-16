class Prawn::SVG::Document
  Error = Class.new(StandardError)
  InvalidSVGData = Class.new(Error)

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
    :color_mode

  def initialize(data, bounds, options, font_registry: nil, css_parser: CssParser::Parser.new, attribute_overrides: {})
    @root = REXML::Document.new(data).root

    if @root.nil?
      if data.respond_to?(:end_with?) && data.end_with?('.svg')
        raise InvalidSVGData,
          "The data supplied is not a valid SVG document.  It looks like you've supplied a filename instead; use IO.read(filename) to get the data before you pass it to prawn-svg."
      else
        raise InvalidSVGData, 'The data supplied is not a valid SVG document.'
      end
    end

    @warnings = []
    @options = options
    @elements_by_id = {}
    @gradients = Prawn::SVG::Gradients.new(self)
    @fallback_font_name = options.fetch(:fallback_font_name, DEFAULT_FALLBACK_FONT_NAME)
    @font_registry = font_registry
    @color_mode = load_color_mode

    @url_loader = Prawn::SVG::UrlLoader.new(
      enable_cache:          options[:cache_images],
      enable_web:            options.fetch(:enable_web_requests, true),
      enable_file_with_root: options[:enable_file_requests_with_root]
    )

    attributes = @root.attributes.dup
    attribute_overrides.each { |key, value| attributes.add(REXML::Attribute.new(key, value)) }

    @sizing = Prawn::SVG::Calculators::DocumentSizing.new(bounds, attributes)
    calculate_sizing(requested_width: options[:width], requested_height: options[:height])

    @element_styles = Prawn::SVG::CSS::Stylesheets.new(css_parser, root).load

    yield self if block_given?
  end

  def calculate_sizing(requested_width: nil, requested_height: nil)
    sizing.requested_width = requested_width
    sizing.requested_height = requested_height
    sizing.calculate
  end

  private

  def load_color_mode
    case @options[:color_mode]
    when nil, :rgb then :rgb
    when :cmyk then :cmyk
    else
      raise ArgumentError, ':color_mode must be set to :rgb (default) or :cmyk'
    end
  end
end
