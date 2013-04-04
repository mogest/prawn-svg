class Prawn::Svg::Color
  # TODO : use http://www.w3.org/TR/SVG11/types.html#ColorKeywords
  HTML_COLORS = {
    'black' => "000000", 'green' => "008000", 'silver' => "c0c0c0", 'lime' => "00ff00",
    'gray' => "808080", 'olive' => "808000", 'white' => "ffffff", 'yellow' => "ffff00",
    'maroon' => "800000", 'navy' => "000080", 'red' => "ff0000", 'blue' => "0000ff",
    'purple' => "800080", 'teal' => "008080", 'fuchsia' => "ff00ff", 'aqua' => "00ffff"
  }.freeze

  RGB_VALUE_REGEXP = "\s*(-?[0-9.]+%?)\s*"
  RGB_REGEXP = /\Argb\(#{RGB_VALUE_REGEXP},#{RGB_VALUE_REGEXP},#{RGB_VALUE_REGEXP}\)\z/i

  def self.color_to_hex(color_string)
    color_string.scan(/([^(\s]+(\([^)]*\))?)/).detect do |color, *_|
      if m = color.match(/\A#([0-9a-f])([0-9a-f])([0-9a-f])\z/i)
        break "#{m[1] * 2}#{m[2] * 2}#{m[3] * 2}"
      elsif color.match(/\A#[0-9a-f]{6}\z/i)
        break color[1..6]
      elsif hex = HTML_COLORS[color.downcase]
        break hex
      elsif m = color.match(RGB_REGEXP)
        break (1..3).collect do |n|
          value = m[n].to_f
          value *= 2.55 if m[n][-1..-1] == '%'
          "%02x" % clamp(value.round, 0, 255)
        end.join
      end
    end
  end

  protected
  def self.clamp(value, min_value, max_value)
    [[value, min_value].max, max_value].min
  end
end
