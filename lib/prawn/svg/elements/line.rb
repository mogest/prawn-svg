class Prawn::SVG::Elements::Line < Prawn::SVG::Elements::Base
  include Prawn::SVG::Pathable

  def parse
    @x1 = points(attributes['x1'] || '0', :x)
    @y1 = points(attributes['y1'] || '0', :y)
    @x2 = points(attributes['x2'] || '0', :x)
    @y2 = points(attributes['y2'] || '0', :y)
  end

  def apply
    apply_commands
    apply_markers
  end

  protected

  def commands
    @commands ||= [
      Prawn::SVG::Pathable::Move.new([@x1, @y1]),
      Prawn::SVG::Pathable::Line.new([@x2, @y2])
    ]
  end
end
