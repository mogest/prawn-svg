class Prawn::Svg::Document
  begin
    require 'css_parser'
    CSS_PARSER_LOADED = true
  rescue LoadError
    CSS_PARSER_LOADED = false
  end

  DEFAULT_FALLBACK_FONT_NAME = "Times-Roman"

  # An +Array+ of warnings that occurred while parsing the SVG data.
  attr_reader :warnings
  attr_writer :url_cache

  attr_reader :root,
    :sizing,
    :cache_images, :fallback_font_name,
    :css_parser, :elements_by_id

  def initialize(data, bounds, options)
    @css_parser = CssParser::Parser.new if CSS_PARSER_LOADED

    @root = REXML::Document.new(data).root
    @warnings = []
    @options = options
    @elements_by_id = {}
    @cache_images = options[:cache_images]
    @fallback_font_name = options.fetch(:fallback_font_name, DEFAULT_FALLBACK_FONT_NAME)

    @sizing = Prawn::Svg::Calculators::DocumentSizing.new(bounds, @root.attributes)
    sizing.requested_width = options[:width]
    sizing.requested_height = options[:height]
    sizing.calculate

    @axis_to_size = {:x => sizing.viewport_width, :y => sizing.viewport_height}

    yield self if block_given?
  end

  def x(value)
    points(value, :x)
  end

  def y(value)
    sizing.output_height - points(value, :y)
  end

  def distance(value, axis = nil)
    value && points(value, axis)
  end

  def points(value, axis = nil)
    Prawn::Svg::Calculators::Pixels.to_pixels(value, @axis_to_size.fetch(axis, sizing.viewport_diagonal))
  end

  def url_loader
    @url_loader ||= Prawn::Svg::UrlLoader.new(:enable_cache => cache_images)
  end
end
