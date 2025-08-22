module Prawn::SVG::Calculators
  module UnitInterval
    private

    def to_unit_interval(string, default = 0)
      string = string.to_s.strip
      return default if string == ''

      value = string.to_f
      value /= 100.0 if string[-1..-1] == '%'
      [0.0, value, 1.0].sort[1]
    end
  end
end
