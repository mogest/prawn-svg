module Prawn::SVG
  class Elements::TextNode
    Chunk = Struct.new(:text, :x, :y, :dx, :dy, :rotate, :base_width, :offset, :fixed_width, :font_runs)

    attr_reader :component, :chunks
    attr_accessor :text

    def initialize(component, text, leading_space, trailing_space)
      @component = component
      @text = text
      @leading_space = leading_space
      @trailing_space = trailing_space
    end

    def leading_space?
      @leading_space
    end

    def trailing_space?
      @trailing_space
    end

    def calculated_width
      @chunks.reduce(0) do |total, chunk|
        total + (chunk.fixed_width || chunk.base_width) + chunk.offset
      end
    end

    def total_flexible_and_fixed_width
      flexible = fixed = 0
      chunks.each do |chunk|
        if chunk.fixed_width.nil?
          flexible += chunk.base_width
          fixed += chunk.offset
        else
          fixed += chunk.offset + chunk.fixed_width
        end
      end
      [flexible, fixed]
    end

    def lay_out(prawn)
      remaining_text = @text
      @chunks = []

      while remaining_text != ''
        x = y = dx = dy = rotate = nil
        remaining = rotation_remaining = false

        comp = component
        while comp
          shifted = comp.x_values.shift
          x ||= shifted
          shifted = comp.y_values.shift
          y ||= shifted
          shifted = comp.dx.shift
          dx ||= shifted
          shifted = comp.dy.shift
          dy ||= shifted

          shifted = comp.rotation.length > 1 ? comp.rotation.shift : comp.rotation.first
          if shifted && rotate.nil?
            rotate = shifted
            remaining ||= comp.rotation != [0]
          end

          remaining ||= comp.x_values.any? || comp.y_values.any? || comp.dx.any? || comp.dy.any? || (rotate && rotate != 0)
          rotation_remaining ||= comp.rotation.length > 1
          comp = comp.parent_component
        end

        rotate = (-rotate if rotate && rotate != 0)

        text_to_draw = remaining ? remaining_text[0..0] : remaining_text

        opts = { size: component.computed_properties.numeric_font_size, kerning: true }

        fallback_fonts = component.fallback_fonts
        font_runs = fallback_fonts&.any? ? split_into_font_runs(prawn, text_to_draw, fallback_fonts) : nil

        letter_spacing = text_to_draw.length > 1 ? (component.letter_spacing_pixels || 0) * (text_to_draw.length - 1) : 0
        word_spacing = (component.word_spacing_pixels || 0) * text_to_draw.count(' ')
        base_width = width_of_text(prawn, text_to_draw, font_runs, opts) + letter_spacing + word_spacing

        offset = dx ? [0, dx].max : 0

        @chunks << Chunk.new(text_to_draw, x, y, dx, dy, rotate, base_width, offset, nil, font_runs)

        if remaining
          remaining_text = remaining_text[1..]
        else
          # we can get to this path with rotations still pending
          # solve this by shifting them out by the number of
          # characters we've just drawn
          shift = remaining_text.length - 1
          if rotation_remaining && shift.positive?
            comp = component
            while comp
              count = [shift, comp.rotation.length - 1].min
              comp.rotation.shift(count) if count.positive?
              comp = comp.parent_component
            end
          end

          break
        end
      end
    end

    def render(prawn, size, cursor, y_offset)
      chunks.each do |chunk|
        cursor.x = chunk.x if chunk.x
        cursor.x += chunk.dx if chunk.dx
        cursor.y = chunk.y if chunk.y
        cursor.y -= chunk.dy if chunk.dy

        width = chunk.fixed_width || chunk.base_width

        unless component.inside_clip_path
          decoration = component.computed_properties.text_decoration
          unless decoration == 'none'
            render_underline(prawn, size, cursor, y_offset, width) if decoration.include?('underline')
            render_overline(prawn, size, cursor, y_offset, width) if decoration.include?('overline')
            render_line_through(prawn, size, cursor, y_offset, width) if decoration.include?('line-through')
          end
          render_link_annotation(prawn, size, cursor, y_offset, width)
        end

        opts = { size: size, at: [cursor.x, cursor.y + (y_offset || 0)], kerning: true }
        opts[:rotate] = chunk.rotate if chunk.rotate

        scaling =
          if chunk.fixed_width && component.current_length_adjust_is_scaling?
            chunk.fixed_width * 100 / chunk.base_width
          else
            100
          end

        spacing_enabled = chunk.fixed_width && !component.current_length_adjust_is_scaling? && chunk.text.length > 1

        # This isn't perfect.  It assumes the parent component which started the textLength context
        # has a character at the end of its text nodes.  If it doesn't, the last character in its
        # children should not take the space.  This is possible but would involve a lot more work so
        # I will park it for now.
        parent_spacing = spacing_enabled && !component.text_length
        spacing =
          if spacing_enabled
            ((chunk.fixed_width - chunk.base_width) / (chunk.text.length - (parent_spacing ? 0 : 1))) + (component.letter_spacing_pixels || 0)
          end

        # Inside clip paths, text renders white in a soft mask to define the
        # clipping region. Override any fill color from the SVG element.
        prawn.fill_color('ffffff') if component.inside_clip_path

        prawn.horizontal_text_scaling(scaling) do
          prawn.character_spacing(spacing || component.letter_spacing_pixels || prawn.character_spacing) do
            prawn.word_spacing(component.word_spacing_pixels || prawn.word_spacing) do
              prawn.text_rendering_mode(calculate_text_rendering_mode) do
                render_text_directly(prawn, chunk.text, chunk.font_runs, opts)
              end
            end
          end
        end

        cursor.x += chunk.fixed_width || chunk.base_width

        # If we're in a textLength context for one of our parents, we'll need to add spacing
        # to the end of our string.  See comment above for why this isn't quite right.
        cursor.x += spacing if parent_spacing
      end
    end

    def width_of_text(prawn, text, font_runs, opts)
      if font_runs.nil?
        prawn.width_of(text, **opts)
      else
        font_runs.sum(0.0) do |font_name, run_text|
          if font_name
            width = nil
            prawn.font(font_name) { width = prawn.width_of(run_text, **opts) }
            width
          else
            prawn.width_of(run_text, **opts)
          end
        end
      end
    end

    def render_text_directly(prawn, text, font_runs, opts)
      if font_runs.nil?
        prawn.draw_text(text, **opts)
      else
        x = opts[:at][0]
        font_runs.each do |font_name, run_text|
          run_opts = opts.merge(at: [x, opts[:at][1]])
          if font_name
            prawn.font(font_name) do
              prawn.draw_text(run_text, **run_opts)
              x += prawn.width_of(run_text, size: opts[:size], kerning: true)
            end
          else
            prawn.draw_text(run_text, **run_opts)
            x += prawn.width_of(run_text, size: opts[:size], kerning: true)
          end
        end
      end
    end

    def split_into_font_runs(prawn, text, fallback_fonts)
      original_font = prawn.font.family
      runs = []
      current_font = nil
      current_text = +''

      prawn.save_font do
        text.each_char do |char|
          font_for_char = font_for_glyph(prawn, char, original_font, fallback_fonts)

          if font_for_char != current_font && !current_text.empty?
            runs << [current_font, current_text]
            current_text = +''
          end
          current_font = font_for_char
          current_text << char
        end
      end

      runs << [current_font, current_text] unless current_text.empty?
      runs
    end

    def font_for_glyph(prawn, char, original_font, fallback_fonts)
      prawn.font(original_font)
      return nil if prawn.font.glyph_present?(char)

      fallback_fonts.each do |fb|
        prawn.font(fb)
        return fb if prawn.font.glyph_present?(char)
      end

      nil
    end

    def render_underline(prawn, size, cursor, y_offset, width)
      offset, thickness = FontMetrics.underline_metrics(prawn, size)

      prawn.fill_rectangle [cursor.x, cursor.y + (y_offset || 0) + offset + (thickness / 2.0)], width, thickness
    end

    def render_overline(prawn, size, cursor, y_offset, width)
      offset, thickness = FontMetrics.overline_metrics(prawn, size)

      prawn.fill_rectangle [cursor.x, cursor.y + (y_offset || 0) + offset + (thickness / 2.0)], width, thickness
    end

    def render_line_through(prawn, size, cursor, y_offset, width)
      offset, thickness = FontMetrics.strikethrough_metrics(prawn, size)

      prawn.fill_rectangle [cursor.x, cursor.y + (y_offset || 0) + offset + (thickness / 2.0)], width, thickness
    end

    def render_link_annotation(prawn, size, cursor, y_offset, width)
      href = component.state.anchor_href
      return unless href

      text_bottom = cursor.y + (y_offset || 0) - scaled_font_size(prawn, :descender, size)
      font_height = scaled_font_size(prawn, :height, size)

      LinkRenderer.new(href, [cursor.x, text_bottom + font_height, cursor.x + width, text_bottom]).render(prawn)
    end

    def scaled_font_size(prawn, method_name, size)
      (prawn.font.public_send(method_name) / prawn.font_size) * size
    end

    def calculate_text_rendering_mode
      return :fill if component.inside_clip_path

      fill = !component.computed_properties.fill.none? # rubocop:disable Style/InverseMethods
      stroke = !component.computed_properties.stroke.none? # rubocop:disable Style/InverseMethods

      if fill && stroke
        :fill_stroke
      elsif fill
        :fill
      elsif stroke
        :stroke
      else
        :invisible
      end
    end
  end
end
