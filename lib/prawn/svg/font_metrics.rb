class Prawn::SVG::FontMetrics
  class << self
    # Default x-height as a fraction of font size (typical for most fonts)
    DEFAULT_X_HEIGHT_RATIO = 0.5

    def x_height_in_points(pdf, font_size)
      ttf = ttf_file(pdf)
      glyph = ttf.glyph_outlines.for(ttf.cmap.unicode.first['x'.ord]) if ttf&.glyph_outlines&.exists?
      height = glyph ? glyph.y_max - glyph.y_min : 0

      (height.positive? ? height / ttf.header.units_per_em.to_f : DEFAULT_X_HEIGHT_RATIO) * font_size
    end

    def underline_metrics(pdf, size)
      if (ttf = ttf_file(pdf))
        scale = size / ttf.header.units_per_em.to_f
        # ttfunk (as of 1.8.0) reads this signed value as unsigned
        top = [ttf.postscript.underline_position].pack('n').unpack1('s>') * scale
        font_thick = ttf.postscript.underline_thickness * scale
      end

      thick = [font_thick&.positive? ? font_thick : size * 0.07, 1.0].max

      # The font gives the top edge of the underline; we return its centre.  An underline at or above the
      # baseline is broken font data, which browsers also refuse to draw.
      offset = top&.negative? ? top - (thick / 2.0) : -0.12 * size

      [offset, thick]
    end

    def overline_metrics(pdf, size)
      [size, underline_metrics(pdf, size).last]
    end

    def strikethrough_metrics(pdf, size)
      ttf = ttf_file(pdf)
      offset = ttf ? ttf.os2.y_strikeout_position * size / ttf.header.units_per_em.to_f : 0.3 * size

      [offset, underline_metrics(pdf, size).last]
    end

    private

    def ttf_file(pdf)
      pdf.font.ttf if pdf.font.is_a?(Prawn::Fonts::TTF)
    end
  end
end
