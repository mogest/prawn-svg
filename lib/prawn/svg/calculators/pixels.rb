module Prawn::SVG::Calculators
  class Pixels
    extend Prawn::Measurements

    def self.to_pixels(value, axis_length)
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
end
