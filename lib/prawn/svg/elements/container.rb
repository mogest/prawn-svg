class Prawn::SVG::Elements::Container < Prawn::SVG::Elements::Base
  def parse
    state.disable_drawing = true if name == "clipPath"
  end

  def apply
    process_child_elements

    raise SkipElementQuietly if %w(symbol defs clipPath).include?(name)
  end

  def container?
    true
  end
end
