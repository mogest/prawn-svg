Prawn::SVG::FuncIRI = Struct.new(:url) do
  def self.parse(value)
    case Prawn::SVG::CSS::ValuesParser.parse(value)
    in [['url', [url]]]
      new(url.strip)
    else
      nil
    end
  end

  def to_s
    "url(#{url})"
  end
end
