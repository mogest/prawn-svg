class Prawn::Svg::Parser::Text
  def parse(element)
    element.add_call_and_enter "text_group"
    internal_parse(element, [element.document.x(0)], [element.document.y(0)])
  end

  protected
  def internal_parse(element, x_positions, y_positions, relative = false, preserve_space = false)
    return if element.state[:display] == "none"

    attrs = element.attributes

    if attrs['x'] || attrs['y']
      relative = false
      x_positions = attrs['x'].split(/[\s,]+/).collect {|n| element.document.x(n)} if attrs['x']
      y_positions = attrs['y'].split(/[\s,]+/).collect {|n| element.document.y(n)} if attrs['y']
    end

    if attrs['dx'] || attrs['dy']
      element.add_call_and_enter "translate", element.document.distance(attrs['dx'] || 0), -element.document.distance(attrs['dy'] || 0)
    end

    case attrs['xml:space']
    when 'preserve'
      preserve_space = true
    when 'default'
      preserve_space = false
    end

    opts = {}
    if size = element.state[:font_size]
      opts[:size] = size
    end
    opts[:style] = element.state[:font_subfamily]

    # This is not a prawn option but we can't work out how to render it here -
    # it's handled by Svg#rewrite_call_arguments
    if (anchor = attrs['text-anchor'] || element.state[:text_anchor]) &&
        ['start', 'middle', 'end'].include?(anchor)
      opts[:text_anchor] = anchor
    end

    if spacing = attrs['letter-spacing']
      element.add_call_and_enter 'character_spacing', element.document.points(spacing)
    end

    element.element.children.each do |child|
      if child.node_type == :text
        text = child.value.strip.gsub(preserve_space ? /[\n\t]/ : /\s+/, " ")

        while text != ""
          opts[:at] = [x_positions.first, y_positions.first]

          if x_positions.length > 1 || y_positions.length > 1
            element.add_call 'draw_text', text[0..0], opts.dup
            text = text[1..-1]

            x_positions.shift if x_positions.length > 1
            y_positions.shift if y_positions.length > 1
          else
            element.add_call relative ? 'relative_draw_text' : 'draw_text', text, opts.dup
            relative = true
            break
          end
        end

      elsif child.name == "tspan"
        element.add_call 'save'
        child.attributes['text-anchor'] ||= opts[:text_anchor] if opts[:text_anchor]
        child_element = Prawn::Svg::Element.new(element.document, child, element.calls, element.state.dup)
        internal_parse(child_element, x_positions, y_positions, relative, preserve_space)
        child_element.append_calls_to_parent
        element.add_call 'restore'

      else
        element.warnings << "Unknown tag '#{child.name}' inside text tag; ignoring"
      end
    end
  end
end
