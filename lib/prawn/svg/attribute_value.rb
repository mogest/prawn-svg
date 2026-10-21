module Prawn::SVG::AttributeValue
  NUMBER_REGEXP = /\A[+-]?\d*\.?\d+(?:e[+-]?\d+)?\z/i.freeze
  PRESERVE_ASPECT_RATIO_REGEXP = /\A(?:defer\s+)?(?:none|x(?:Min|Mid|Max)Y(?:Min|Mid|Max))(?:\s+(?:meet|slice))?\z/.freeze

  # Whether prawn-svg can use the value for an attribute of the given type
  def self.valid?(type, value)
    # Keywords are compared exactly where they're used, so must match exactly here too
    return type.include?(value) if type.is_a?(Array)

    value = value.strip

    case type
    when :length then length?(value)
    when :number_or_percentage then number?(value) || Prawn::SVG::Percentage.parse(value)
    when :length_list then list(value).all? { |item| length?(item) }
    when :number_list then list(value).all? { |item| number?(item) }
    when :view_box then view_box?(list(value))
    when :preserve_aspect_ratio then value.match?(PRESERVE_ASPECT_RATIO_REGEXP)
    when :orient then value == 'auto' || Prawn::SVG::Angle.parse(value)
    else raise ArgumentError, "Unknown attribute type #{type.inspect}"
    end
  end

  def self.length?(value)
    Prawn::SVG::Length.parse(value) || Prawn::SVG::Percentage.parse(value)
  end

  def self.number?(value)
    value.match?(NUMBER_REGEXP)
  end

  def self.list(value)
    value.split(Prawn::SVG::Elements::COMMA_WSP_REGEXP)
  end

  def self.view_box?(values)
    values.length == 4 && values.all? { |item| number?(item) } && values[2].to_f >= 0 && values[3].to_f >= 0
  end
end
