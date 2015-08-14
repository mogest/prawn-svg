class Prawn::SVG::Elements::Style < Prawn::SVG::Elements::Base
  def parse
    if @document.css_parser
      data = source.texts.map(&:value).join
      @document.css_parser.add_block!(data)
    end

    raise SkipElementQuietly
  end
end
