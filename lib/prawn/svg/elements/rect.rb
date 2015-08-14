class Prawn::SVG::Elements::Rect < Prawn::SVG::Elements::Base
  def parse
    require_attributes 'width', 'height'

    @x = x(attributes['x'] || '0')
    @y = y(attributes['y'] || '0')
    @width = distance(attributes['width'], :x)
    @height = distance(attributes['height'], :y)
    @radius = distance(attributes['rx'] || attributes['ry'])

    require_positive_value @width, @height
  end

  def apply
    if @radius
      # n.b. does not support both rx and ry being specified with different values
      add_call "rounded_rectangle", [@x, @y], @width, @height, @radius
    else
      add_call "rectangle", [@x, @y], @width, @height
    end
  end

  def bounding_box
    [@x, @y, @x + width, @y + height]
  end
end
