module Prawn::SVG
  class Elements::TextPath < Elements::TextComponent
    def parse
      href = href_attribute
      unless href&.start_with?('#')
        warnings << '<textPath> must reference a path element'
        raise SkipElementQuietly
      end

      @path_element = document.elements_by_id[href[1..]]
      unless @path_element.is_a?(Elements::Path)
        warnings << "<textPath> reference '#{href}' is not a path element"
        raise SkipElementQuietly
      end

      @path_length = Calculators::PathLength.new(@path_element.commands)

      raise SkipElementQuietly if @path_length.total_length <= 0

      @start_offset = parse_start_offset

      super
    end

    def render_component(prawn, renderer, _cursor, _translate_x = nil, accumulated_baseline_shift = 0)
      raise SkipElementQuietly if computed_properties.display == 'none'

      add_yield_call do
        size = computed_properties.numeric_font_size
        y_offset = dominant_baseline_offset(prawn, size || prawn.font_size) || 0

        with_svg_fonts(prawn) do
          total_baseline_shift = accumulated_baseline_shift + baseline_shift_offset(prawn, size)
          y_offset += total_baseline_shift

          current_distance = @start_offset
          render_children_along_path(prawn, children, size, y_offset, current_distance)
        end
      end

      renderer.render_calls(prawn, base_calls)
    end

    def transformable?
      false
    end

    private

    def render_children_along_path(prawn, children, size, y_offset, current_distance)
      children.each do |child|
        case child
        when Elements::TextNode
          current_distance = render_text_node_along_path(prawn, child, size, y_offset, current_distance)
        when Elements::TextComponent
          prawn.save_graphics_state
          child_size = child.computed_properties.numeric_font_size
          child_y_offset = child.dominant_baseline_offset(prawn, child_size || prawn.font_size)
          child.with_svg_fonts(prawn) do
            current_distance = render_children_along_path(prawn, child.children, child_size, child_y_offset, current_distance)
          end
          prawn.restore_graphics_state
        end
      end

      current_distance
    end

    def render_text_node_along_path(prawn, text_node, size, y_offset, current_distance)
      text_node.chunks.each do |chunk|
        advances = kerned_advances(prawn, text_node, chunk.text, size)

        chunk.text.each_char.with_index do |char, i|
          char_width = text_node.width_of_text(prawn, char, nil, { size: size, kerning: false })
          advance = advances[i]

          midpoint = current_distance + (char_width / 2.0)
          point = @path_length.point_at(midpoint)
          break unless point

          mid_x, mid_y_svg, angle = point
          angle_rad = angle * Math::PI / 180.0
          half_width = char_width / 2.0

          # Offset back from midpoint to left edge along the tangent
          px = mid_x - (half_width * Math.cos(angle_rad))
          py_svg = mid_y_svg - (half_width * Math.sin(angle_rad))
          py = document.sizing.output_height - py_svg

          draw_opts = { size: size, at: [px, py + (y_offset || 0)] }
          draw_opts[:rotate] = -angle

          render_mode = calculate_text_rendering_mode(text_node.component)

          prawn.text_rendering_mode(render_mode) do
            text_node.render_text_directly(prawn, char, nil, draw_opts)
          end

          current_distance += advance
        end
      end

      current_distance
    end

    # Compute the advance width for each character, accounting for kerning
    # with the following character. The advance is the character's own width
    # plus any kerning adjustment with its neighbour.
    def kerned_advances(prawn, text_node, text, size)
      opts_no_kern = { size: size, kerning: false }
      opts_kern = { size: size, kerning: true }

      text.each_char.with_index.map do |char, i|
        char_width = text_node.width_of_text(prawn, char, nil, opts_no_kern)
        next_char = text[i + 1]

        if next_char
          pair_width = text_node.width_of_text(prawn, "#{char}#{next_char}", nil, opts_kern)
          next_width = text_node.width_of_text(prawn, next_char, nil, opts_no_kern)
          char_width + (pair_width - char_width - next_width)
        else
          char_width
        end
      end
    end

    def calculate_text_rendering_mode(component)
      fill = component.computed_properties.fill.any?
      stroke = component.computed_properties.stroke.any?

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

    def parse_start_offset
      value = attributes['startOffset']
      return 0.0 unless value

      if value.end_with?('%')
        @path_length.total_length * value.to_f / 100.0
      else
        x_pixels(value)
      end
    end
  end
end
