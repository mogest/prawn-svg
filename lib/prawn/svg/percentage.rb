Prawn::SVG::Percentage = Struct.new(:value)

class Prawn::SVG::Percentage
  REGEXP = /\A([+-]?\d*(?:\.\d+)?)%\z/i.freeze

  def self.parse(value, positive_only: false)
    if (matches = value.match(REGEXP))
      number = Float(matches[1], exception: false)
      new(number) if number && (!positive_only || number >= 0)
    end
  end

  def to_f
    value
  end

  def to_factor
    value / 100.0
  end

  def to_pixels(axis_length, _font_size)
    value * axis_length / 100.0
  end
end
