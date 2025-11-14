class Prawn::SVG::Elements::Anchor < Prawn::SVG::Elements::Base
  def parse
    state.anchor_href = href_attribute
  end

  def container?
    true
  end
end
