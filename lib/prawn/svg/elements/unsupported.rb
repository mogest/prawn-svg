class Prawn::SVG::Elements::Unsupported < Prawn::SVG::Elements::Base
  def process
    document.add_issue(:unsupported, "Unsupported tag '#{name}'; ignoring")
  end
end
