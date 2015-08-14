class Prawn::SVG::Elements::Line < Prawn::SVG::Elements::Base
  def parse
    @x1 = x(attributes['x1'] || '0')
    @y1 = y(attributes['y1'] || '0')
    @x2 = x(attributes['x2'] || '0')
    @y2 = y(attributes['y2'] || '0')
  end

  def apply
    add_call 'line', @x1, @y1, @x2, @y2
  end

  def bounding_box
    [@x1, @y1, @x2, @y2]
  end
end
