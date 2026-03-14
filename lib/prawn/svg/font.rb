module Prawn::SVG
  class Font
    attr_reader :name, :weight, :style, :stretch

    def initialize(name, weight, style, stretch = nil)
      @name = name
      @weight = weight
      @style = style
      @stretch = stretch
    end

    def subfamily
      parts = []
      parts << stretch if stretch && stretch != :normal
      parts << weight if weight && weight != :normal
      parts << style if style
      parts.empty? ? :normal : parts.join('_').to_sym
    end
  end
end
