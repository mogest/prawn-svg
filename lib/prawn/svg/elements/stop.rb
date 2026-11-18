# Read by its gradient for its attributes and properties; it doesn't draw anything.
class Prawn::SVG::Elements::Stop < Prawn::SVG::Elements::Base
  def parse_and_apply; end

  def color
    computed_properties.stop_color == 'currentcolor' ? computed_properties.color : computed_properties.stop_color
  end
end
