class Prawn::SVG::Elements::Polyline < Prawn::SVG::Elements::Base
  def parse
    require_attributes('points')
    @points = parse_points(attributes['points'])
  end

  def apply
    raise SkipElementQuietly unless @points.length > 0

    add_call 'move_to', *@points[0]
    add_call_and_enter 'stroke'
    @points[1..-1].each do |x, y|
      add_call "line_to", x, y
    end
  end

  def bounding_box
    x1, x2 = @points.minmax(&:first)
    y1, y2 = @points.minmax(&:last)
    [x1, y1, x2, y2]
  end
end
