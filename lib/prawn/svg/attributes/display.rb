module Prawn::SVG::Attributes::Display
  def parse_display_attribute
    @state[:display] = attributes['display'].strip if attributes['display']
  end
end
