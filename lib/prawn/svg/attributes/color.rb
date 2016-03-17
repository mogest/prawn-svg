module Prawn::SVG::Attributes::Color
  def parse_color_attribute
    state.color = attributes['color'] if attributes['color']
  end
end
