module Prawn::SVG::Elements
  COMMA_WSP_REGEXP = /(?:\s+,?\s*|,\s*)/
end

%w(base root container style text line polyline polygon circle ellipse rect path use image ignored).each do |filename|
  require "prawn/svg/elements/#{filename}"
end

module Prawn::SVG::Elements
  TAG_CLASS_MAPPING = {
    svg: Prawn::SVG::Elements::Container,
    g: Prawn::SVG::Elements::Container,
    symbol: Prawn::SVG::Elements::Container,
    defs: Prawn::SVG::Elements::Container,
    clipPath: Prawn::SVG::Elements::Container,
    style: Prawn::SVG::Elements::Style,
    text: Prawn::SVG::Elements::Text,
    line: Prawn::SVG::Elements::Line,
    polyline: Prawn::SVG::Elements::Polyline,
    polygon: Prawn::SVG::Elements::Polygon,
    circle: Prawn::SVG::Elements::Circle,
    ellipse: Prawn::SVG::Elements::Ellipse,
    rect: Prawn::SVG::Elements::Rect,
    path: Prawn::SVG::Elements::Path,
    use: Prawn::SVG::Elements::Use,
    image: Prawn::SVG::Elements::Image,
    title: Prawn::SVG::Elements::Ignored,
    desc: Prawn::SVG::Elements::Ignored,
    metadata: Prawn::SVG::Elements::Ignored,
    :"font-face" => Prawn::SVG::Elements::Ignored,
  }
end
