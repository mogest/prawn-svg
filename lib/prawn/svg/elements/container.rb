class Prawn::SVG::Elements::Container < Prawn::SVG::Elements::Base
  def parse
    state.disable_drawing = true if name == 'clipPath'

    if %w(symbol defs clipPath).include?(name)
      properties.display = 'none'
      computed_properties.display = 'none'
    end
  end

  def container?
    true
  end
end
