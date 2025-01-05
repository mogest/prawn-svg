module Prawn::SVG::Calculators::Pixels
  class Measurement
    def self.to_pixels(value, axis_length = nil, font_size: Prawn::SVG::Properties::EM)
      if value.respond_to?(:to_pixels)
        value.to_pixels(axis_length, font_size)
      elsif value.is_a?(String)
        value = value.strip
        value = Prawn::SVG::Length.parse(value) || Prawn::SVG::Percentage.parse(value)
        value&.to_pixels(axis_length, font_size) || 0.0
      elsif value
        value.to_f
      end
    end
  end

  protected

  def x(value)
    x_pixels(value)
  end

  def y(value)
    # This uses document.sizing, not state.viewport_sizing, because we always
    # want to subtract from the total height of the document.
    document.sizing.output_height - y_pixels(value)
  end

  def pixels(value)
    value && Measurement.to_pixels(value, state.viewport_sizing.viewport_diagonal,
      font_size: computed_properties.numeric_font_size)
  end

  def x_pixels(value)
    value && Measurement.to_pixels(value, state.viewport_sizing.viewport_width,
      font_size: computed_properties.numeric_font_size)
  end

  def y_pixels(value)
    value && Measurement.to_pixels(value, state.viewport_sizing.viewport_height,
      font_size: computed_properties.numeric_font_size)
  end
end
