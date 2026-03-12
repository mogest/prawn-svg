class Prawn::SVG::Elements::Rect < Prawn::SVG::Elements::Base
  include Prawn::SVG::Calculators::ArcToBezierCurve

  def parse
    require_attributes 'width', 'height'

    @x = x(attributes['x'] || '0')
    @y = y(attributes['y'] || '0')
    @width = x_pixels(attributes['width'])
    @height = y_pixels(attributes['height'])

    require_positive_value @width, @height

    raw_rx = x_pixels(attributes['rx'])
    raw_ry = y_pixels(attributes['ry'])

    if raw_rx || raw_ry
      @rx = (raw_rx || raw_ry).clamp(0, @width / 2.0)
      @ry = (raw_ry || raw_rx).clamp(0, @height / 2.0)
    end
  end

  def apply
    if @rx && @ry
      if @rx == @ry
        add_call 'rounded_rectangle', [@x, @y], @width, @height, @rx
      else
        apply_elliptical_rounded_rectangle
      end
    else
      add_call 'rectangle', [@x, @y], @width, @height
    end
  end

  def bounding_box
    [@x, @y, @x + @width, @y - @height]
  end

  private

  def apply_elliptical_rounded_rectangle
    x1 = @x
    y1 = @y
    x2 = @x + @width
    y2 = @y - @height

    add_call 'move_to', [x1 + @rx, y1]
    add_call 'line_to', [x2 - @rx, y1]
    add_arc x2 - @rx, y1 - @ry, Math::PI / 2, 0
    add_call 'line_to', [x2, y2 + @ry]
    add_arc x2 - @rx, y2 + @ry, 0, -Math::PI / 2
    add_call 'line_to', [x1 + @rx, y2]
    add_arc x1 + @rx, y2 + @ry, -Math::PI / 2, -Math::PI
    add_call 'line_to', [x1, y1 - @ry]
    add_arc x1 + @rx, y1 - @ry, Math::PI, Math::PI / 2
    add_call 'close_path'
  end

  def add_arc(cx, cy, start_angle, end_angle)
    calculate_bezier_curve_points_for_arc(cx, cy, @rx, @ry, start_angle, end_angle, 0).each do |points|
      add_call 'curve_to', points[:p2], bounds: [points[:q1], points[:q2]]
    end
  end
end
