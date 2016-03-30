class Prawn::SVG::Font
  GENERIC_CSS_FONT_MAPPING = {
    "serif"      => "Times-Roman",
    "sans-serif" => "Helvetica",
    "cursive"    => "Times-Roman",
    "fantasy"    => "Times-Roman",
    "monospace"  => "Courier"
  }

  attr_reader :name, :weight, :style

  def self.weight_for_css_font_weight(weight)
    case weight
    when '100', '200', '300' then :light
    when '400', '500'        then :normal
    when '600'               then :semibold
    when '700', 'bold'       then :bold
    when '800'               then :extrabold
    when '900'               then :black
    end
  end

  def initialize(name, weight, style, font_registry: self.font_registry)
    name = GENERIC_CSS_FONT_MAPPING.fetch(name, name) # If it's a standard CSS font name, map it to one of the standard PDF fonts.

    @font_registry = font_registry
    @name = font_registry.correctly_cased_font_name(name) || name
    @weight = weight
    @style = style
  end

  def installed?
    subfamilies = @font_registry.installed_fonts[name]
    !subfamilies.nil? && subfamilies.key?(subfamily)
  end

  # Construct a subfamily name, ensuring that the subfamily is a valid one for the font.
  def subfamily
    if subfamilies = @font_registry.installed_fonts[name]
      if subfamilies.key?(subfamily_name)
        subfamily_name
      elsif subfamilies.key?(:normal)
        :normal
      else
        subfamilies.keys.first
      end
    end
  end

  private

  # Construct a subfamily name from the weight and style information.
  # Note that this name might not actually exist in the font.
  def subfamily_name
    sfn = if weight == :normal && style
      style
    elsif weight || style
      "#{weight} #{style}"
    else
      "normal"
    end

    sfn.strip.gsub(/\s+/, "_").downcase.to_sym
  end
end
