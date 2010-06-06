class Prawn::Svg::Document
  include Prawn::Measurements

  begin
    require 'css_parser'
    CSS_PARSER_LOADED = true
  rescue LoadError
    CSS_PARSER_LOADED = false
  end    
  
  DEFAULT_WIDTH  = 640
  DEFAULT_HEIGHT = 480
  
  # An +Array+ of warnings that occurred while parsing the SVG data.
  attr_reader :warnings

  # The scaling factor, as determined by the :width or :height options.
  attr_accessor :scale

  attr_reader :root,
    :actual_width, :actual_height, :width, :height, :x_offset, :y_offset,
    :css_parser
    
  def initialize(data, bounds, options)
    @css_parser = CssParser::Parser.new if CSS_PARSER_LOADED

    @root = REXML::Document.new(data).root
    @warnings = []
    @options = options
    @actual_width, @actual_height = bounds # set this first so % width/heights can be used

    if vb = @root.attributes['viewBox']
      x1, y1, x2, y2 = vb.strip.split(/\s+/)
      @x_offset, @y_offset = [x1.to_f, y1.to_f]
      @actual_width, @actual_height = [x2.to_f - x1.to_f, y2.to_f - y1.to_f]
    else
      @x_offset, @y_offset = [0, 0]
      @actual_width = points(@root.attributes['width'] || DEFAULT_WIDTH, :x)
      @actual_height = points(@root.attributes['height'] || DEFAULT_HEIGHT, :y)
    end
    
    if @options[:width]
      @width = @options[:width]      
      @scale = @options[:width] / @actual_width.to_f
    elsif @options[:height]
      @height = @options[:height]
      @scale = @options[:height] / @actual_height.to_f
    else
      @scale = 1
    end

    @width ||= @actual_width * @scale
    @height ||= @actual_height * @scale    
  end
  
  def x(value)
    (points(value, :x) - @x_offset) * scale
  end

  def y(value)
    (@actual_height - (points(value, :y) - @y_offset)) * scale
  end

  def distance(value, axis = nil)
    value && (points(value, axis) * scale)
  end

  def points(value, axis = nil)
    if value.is_a?(String)
      if match = value.match(/\d(cm|dm|ft|in|m|mm|yd)$/)
        send("#{match[1]}2pt", value.to_f)
      elsif value[-1..-1] == "%"
        value.to_f * (axis == :y ? @actual_height : @actual_width) / 100.0
      else
        value.to_f
      end
    else
      value.to_f
    end
  end
end
