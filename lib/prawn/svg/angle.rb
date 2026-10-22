module Prawn::SVG::Angle
  REGEXP = /\A([+-]?\d*(?:\.\d+)?(?:e[+-]?\d+)?)(deg|grad|rad)?\z/i.freeze
  DEGREES_PER_UNIT = { nil => 1, 'deg' => 1, 'grad' => 0.9, 'rad' => 180 / Math::PI }.freeze

  # Returns the angle in degrees, or nil if it can't be parsed
  def self.parse(value)
    matches = value.strip.match(REGEXP) or return
    number = Float(matches[1], exception: false) or return

    number * DEGREES_PER_UNIT[matches[2]&.downcase]
  end
end
