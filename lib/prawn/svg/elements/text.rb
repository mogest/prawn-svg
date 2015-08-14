class Prawn::SVG::Elements::Text < Prawn::SVG::Elements::Base
  def parse
    case attributes['xml:space']
    when 'preserve'
      state[:preserve_space] = true
    when 'default'
      state[:preserve_space] = false
    end

    @relative = state[:text_relative] || false

    if attributes['x'] || attributes['y']
      @relative = false
      @x_positions = attributes['x'].split(COMMA_WSP_REGEXP).collect {|n| document.x(n)} if attributes['x']
      @y_positions = attributes['y'].split(COMMA_WSP_REGEXP).collect {|n| document.y(n)} if attributes['y']
    end

    @x_positions ||= state[:text_x_positions] || [document.x(0)]
    @y_positions ||= state[:text_y_positions] || [document.y(0)]
  end

  def apply
    raise SkipElementQuietly if state[:display] == "none"

    add_call_and_enter "text_group" if name == 'text'

    if attributes['dx'] || attributes['dy']
      add_call_and_enter "translate", document.distance(attributes['dx'] || 0), -document.distance(attributes['dy'] || 0)
    end

    opts = {}
    if size = state[:font_size]
      opts[:size] = size
    end
    opts[:style] = state[:font_subfamily]

    # This is not a prawn option but we can't work out how to render it here -
    # it's handled by SVG#rewrite_call_arguments
    if (anchor = attributes['text-anchor'] || state[:text_anchor]) &&
        ['start', 'middle', 'end'].include?(anchor)
      opts[:text_anchor] = anchor
    end

    if spacing = attributes['letter-spacing']
      add_call_and_enter 'character_spacing', document.points(spacing)
    end

    source.children.each do |child|
      if child.node_type == :text
        text = child.value.strip.gsub(state[:preserve_space] ? /[\n\t]/ : /\s+/, " ")

        while text != ""
          opts[:at] = [@x_positions.first, @y_positions.first]

          if @x_positions.length > 1 || @y_positions.length > 1
            # TODO : isn't this just text.shift ?
            add_call 'draw_text', text[0..0], opts.dup
            text = text[1..-1]

            @x_positions.shift if @x_positions.length > 1
            @y_positions.shift if @y_positions.length > 1
          else
            add_call @relative ? 'relative_draw_text' : 'draw_text', text, opts.dup
            @relative = true
            break
          end
        end

      elsif child.name == "tspan"
        add_call 'save'

        new_state = state.dup
        new_state[:text_x_positions] = @x_positions
        new_state[:text_y_positions] = @y_positions
        new_state[:text_relative] = @relative
        new_state[:text_anchor] = opts[:text_anchor]

        Prawn::SVG::Elements::Text.new(document, child, calls, new_state).process

        add_call 'restore'

      else
        warnings << "Unknown tag '#{child.name}' inside text tag; ignoring"
      end
    end
  end
end
