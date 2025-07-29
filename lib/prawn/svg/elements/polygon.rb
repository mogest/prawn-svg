class Prawn::SVG::Elements::Polygon < Prawn::SVG::Elements::Base
  include Prawn::SVG::Pathable

  def parse
    require_attributes('points')
    @points = parse_points(attributes['points'])
  end

  def apply
    apply_commands
    apply_markers
  end

  protected

  def commands
    @commands ||= [
      Prawn::SVG::Pathable::Move.new(@points[0])
    ] + @points[1..].map do |point|
      Prawn::SVG::Pathable::Line.new(point)
    end + [
      Prawn::SVG::Pathable::Close.new(@points[0])
    ]
  end
end
