module Prawn
  class Document
    def svg(data, options={})
      Prawn::Svg.new(data, self, options).draw
    end
  end
end
