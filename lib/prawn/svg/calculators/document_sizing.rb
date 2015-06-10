module Prawn::Svg::Calculators
  class DocumentSizing
    DEFAULT_WIDTH = "100%"
    DEFAULT_HEIGHT = "100%"
    DEFAULT_ASPECT_RATIO = "xMidYMid meet"

    attr_writer :document_width, :document_height
    attr_writer :view_box, :preserve_aspect_ratio
    attr_writer :requested_width, :requested_height

    attr_reader :bounds
    attr_reader :x_offset, :y_offset, :x_scale, :y_scale
    attr_reader :viewport_width, :viewport_height, :viewport_diagonal, :output_width, :output_height

    def initialize(bounds, attributes = nil)
      @bounds = bounds
      set_from_attributes(attributes) if attributes
    end

    def set_from_attributes(attributes)
      @document_width = attributes['width'] || DEFAULT_WIDTH
      @document_height = attributes['height'] || DEFAULT_HEIGHT
      @view_box = attributes['viewBox']
      @preserve_aspect_ratio = attributes['preserveAspectRatio'] || DEFAULT_ASPECT_RATIO
    end

    def calculate
      @x_offset = @y_offset = 0
      @x_scale = @y_scale = 1

      width = Prawn::Svg::Calculators::Pixels.to_pixels(@document_width, @requested_width || @bounds[0])
      height = Prawn::Svg::Calculators::Pixels.to_pixels(@document_height, @requested_height || @bounds[1])

      if @view_box
        values = @view_box.strip.split(Prawn::Svg::Parser::COMMA_WSP_REGEXP)
        @x_offset, @y_offset, @viewport_width, @viewport_height = values.map {|value| value.to_f}
        @x_offset = -@x_offset

        aspect = Prawn::Svg::Calculators::AspectRatio.new(@preserve_aspect_ratio, [width, height], [@viewport_width, @viewport_height])
        @x_scale = aspect.width / @viewport_width
        @y_scale = aspect.height / @viewport_height
        @x_offset -= aspect.x / @x_scale
        @y_offset -= aspect.y / @y_scale
      else
        @viewport_width = width
        @viewport_height = height
      end

      # SVG 1.1 section 7.10
      @viewport_diagonal = Math.sqrt(@viewport_width**2 + @viewport_height**2) / Math.sqrt(2)

      if @requested_width
        scale = @requested_width / width
        width = @requested_width
        height *= scale
        @x_scale *= scale
        @y_scale *= scale

      elsif @requested_height
        scale = @requested_height / height
        height = @requested_height
        width *= scale
        @x_scale *= scale
        @y_scale *= scale
      end

      @output_width = width
      @output_height = height

      self
    end
  end
end
