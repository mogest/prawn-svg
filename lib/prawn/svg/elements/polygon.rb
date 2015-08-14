class Prawn::SVG::Elements::Polygon < Prawn::SVG::Elements::Base
  def parse
    require_attributes('points')
    @points = parse_points(attributes['points'])
  end

  def apply
    add_call 'polygon', *@points
  end

  def bounding_box
    x1, x2 = @points.minmax(&:first)
    y1, y2 = @points.minmax(&:last)
    [x1, y1, x2, y2]
  end
end

