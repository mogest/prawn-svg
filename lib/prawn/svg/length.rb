module Prawn::SVG
  Length = Struct.new(:value, :unit)

  class Length
    REGEXP = /\A([+-]?\d*(?:\.\d+)?)(em|rem|ex|px|in|cm|mm|pt|pc)?\z/i.freeze

    def self.parse(value, positive_only: false)
      if (matches = value.match(REGEXP))
        number = Float(matches[1], exception: false)
        new(number, matches[2]&.downcase&.to_sym) if number && (!positive_only || number >= 0)
      end
    end

    def to_f
      value
    end

    def to_s
      "#{value}#{unit}"
    end

    def to_pixels(_axis_length, font_size)
      case unit
      when :em
        value * font_size
      when :rem
        value * Properties::EM
      when :ex
        value * (font_size / 2.0) # we don't have access to the x-height, so this is an approximation approved by the CSS spec
      when :pc
        value * 15 # according to http://www.w3.org/TR/SVG11/coords.html
      when :in
        value * 72
      when :cm
        value * 10 * (72 / 25.4)
      when :mm
        value * (72 / 25.4)
      else
        value
      end
    end
  end
end
