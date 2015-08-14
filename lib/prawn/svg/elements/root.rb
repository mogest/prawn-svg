class Prawn::SVG::Elements::Root < Prawn::SVG::Elements::Base
  def apply
    add_call 'fill_color', '000000'
    add_call 'transformation_matrix', @document.sizing.x_scale, 0, 0, @document.sizing.y_scale, 0, 0
    add_call 'transformation_matrix', 1, 0, 0, 1, @document.sizing.x_offset, @document.sizing.y_offset

    process_child_elements
  end
end
