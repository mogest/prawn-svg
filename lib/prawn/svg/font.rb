module Prawn::SVG
  class Font
    attr_reader :name, :weight, :style

    def initialize(name, weight, style)
      @name = name
      @weight = weight
      @style = style
    end

    def subfamily
      if weight == :normal && style
        style
      elsif weight || style
        [weight, style].compact.join('_').to_sym
      else
        :normal
      end
    end
  end
end
