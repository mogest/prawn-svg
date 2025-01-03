class Prawn::SVG::Elements::Root < Prawn::SVG::Elements::Base
  def initialize(document, source = document.root, parent_calls = [], state = ::Prawn::SVG::State.new)
    super
  end

  def parse
    state.viewport_sizing = @document.sizing
  end

  def apply
    if [nil, 'inherit', 'none', 'currentcolor'].include?(properties.fill)
      add_call 'fill_color', Prawn::SVG::Color.default_color(@document.color_mode).value
    end

    add_call 'transformation_matrix', @document.sizing.x_scale, 0, 0, @document.sizing.y_scale, 0, 0
    add_call 'transformation_matrix', 1, 0, 0, 1, -@document.sizing.x_offset, @document.sizing.y_offset
  end

  def container?
    true
  end
end
