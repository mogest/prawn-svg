class Prawn::SVG::Elements::Container < Prawn::SVG::Elements::Base
  def parse
    set_display_none if name == 'symbol' && !state.inside_use
    set_display_none if name == 'defs'
  end

  def container?
    true
  end
end
