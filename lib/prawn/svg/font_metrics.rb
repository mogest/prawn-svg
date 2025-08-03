class Prawn::SVG::FontMetrics
  class << self
    # Default x-height as a fraction of font size (typical for most fonts)
    DEFAULT_X_HEIGHT_RATIO = 0.5

    def x_height_in_points(pdf, font_size)
      @x_height_cache ||= {}

      cache_key = cache_key_for(pdf)

      @x_height_cache[cache_key] ||= calculate_x_height_ratio(pdf)
      @x_height_cache[cache_key] * font_size
    end

    def underline_metrics(pdf, size)
      @underline_metrics_cache ||= {}

      cache_key = cache_key_for(pdf)

      @underline_metrics_cache[cache_key] ||= fetch_underline_metrics(pdf, size)
      @underline_metrics_cache[cache_key]
    end

    private

    def cache_key_for(pdf)
      return 'default' unless pdf && pdf.font.is_a?(Prawn::Fonts::TTF)

      ttf = pdf.font.ttf
      return 'default' unless ttf

      # Use font family name from TTF metadata, which doesn't include size
      ttf.name&.font_family&.first || pdf&.font&.name || 'default'
    end

    def calculate_x_height_ratio(pdf)
      return DEFAULT_X_HEIGHT_RATIO unless pdf && pdf.font.is_a?(Prawn::Fonts::TTF)

      ttf = pdf.font.ttf
      return DEFAULT_X_HEIGHT_RATIO unless ttf

      units_per_em = ttf.header&.units_per_em&.to_f
      return DEFAULT_X_HEIGHT_RATIO unless units_per_em&.positive?

      cmap = ttf.cmap&.unicode&.first
      return DEFAULT_X_HEIGHT_RATIO unless cmap

      xid = cmap['x'.ord]
      return DEFAULT_X_HEIGHT_RATIO unless xid

      bbox = ttf.glyph_outlines&.for(xid)
      return DEFAULT_X_HEIGHT_RATIO unless bbox

      y_max = bbox.y_max
      y_min = bbox.y_min
      return DEFAULT_X_HEIGHT_RATIO unless y_max && y_min

      glyph_height_units = y_max - y_min
      return DEFAULT_X_HEIGHT_RATIO if glyph_height_units <= 0

      glyph_height_units / units_per_em
    end

    def fetch_underline_metrics(pdf, size)
      units_per_em = nil
      pos_units = thick_units = nil
      if pdf.font.is_a?(Prawn::Font::TTF)
        ttf = begin
          pdf.font.ttf
        rescue StandardError
          nil
        end
        if ttf.respond_to?(:post) && ttf.post && ttf.respond_to?(:header) && ttf.header
          units_per_em = ttf.header.units_per_em.to_f
          pos_units = ttf.post.underline_position.to_f
          thick_units = ttf.post.underline_thickness.to_f
        end
      end

      offset =
        if units_per_em && pos_units
          (pos_units / units_per_em) * size
        else
          -0.12 * size
        end

      thick =
        if units_per_em && thick_units&.positive?
          [(thick_units / units_per_em) * size, 0.5].max
        else
          [size * 0.06, 0.5].max
        end

      [offset, thick]
    end
  end
end
