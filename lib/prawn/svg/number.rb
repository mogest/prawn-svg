module Prawn::SVG::Number
  REGEXP = /\A[+-]?(?:\d*\.\d+|\d+)(?:e[+-]?\d+)?\z/i.freeze

  # SVG 1.1 numbers are single precision.  Limiting them to its range also keeps the arithmetic done with them finite.
  MAX = 3.4028235e38
  MIN_NONZERO = 1.17549435e-38

  # Returns the number as a Float, or nil if it isn't a usable number
  def self.parse(string)
    return unless string.match?(REGEXP)

    number = Float(string)
    return if number.abs > MAX

    number.abs < MIN_NONZERO ? 0.0 : number
  end
end
