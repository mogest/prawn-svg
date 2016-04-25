module Prawn::SVG::Calculators::Pixels
  class Measurement
    extend Prawn::Measurements

    def self.to_pixels(value, axis_length = nil)
      if value.is_a?(String)
        if match = value.match(/\d(cm|dm|ft|in|m|mm|yd)$/)
          send("#{match[1]}2pt", value.to_f)
        elsif match = value.match(/\dpc$/)
          value.to_f * 15 # according to http://www.w3.org/TR/SVG11/coords.html
        elsif value[-1..-1] == "%"
          value.to_f * axis_length / 100.0
        else
          value.to_f
        end
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
    value && Measurement.to_pixels(value, state.viewport_sizing.viewport_diagonal)
  end

  def x_pixels(value)
    value && Measurement.to_pixels(value, state.viewport_sizing.viewport_width)
  end

  def y_pixels(value)
    value && Measurement.to_pixels(value, state.viewport_sizing.viewport_height)
  end
end
