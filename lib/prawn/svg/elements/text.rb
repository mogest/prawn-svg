class Prawn::SVG::Elements::Text < Prawn::SVG::Elements::Base
  def parse
    case attributes['xml:space']
    when 'preserve'
      state.preserve_space = true
    when 'default'
      state.preserve_space = false
    end

    @relative = state.text_relative || false

    if attributes['x'] || attributes['y']
      @relative = false
      @x_positions = attributes['x'].split(COMMA_WSP_REGEXP).collect {|n| document.x(n)} if attributes['x']
      @y_positions = attributes['y'].split(COMMA_WSP_REGEXP).collect {|n| document.y(n)} if attributes['y']
    end

    @x_positions ||= state.text_x_positions || [document.x(0)]
    @y_positions ||= state.text_y_positions || [document.y(0)]
  end

  def apply
    raise SkipElementQuietly if computed_properties.display == "none"

    font = select_font
    apply_font(font) if font

    add_call_and_enter "text_group" if name == 'text'

    if attributes['dx'] || attributes['dy']
      add_call_and_enter "translate", document.distance(attributes['dx'] || 0), -document.distance(attributes['dy'] || 0)
    end

    # text_anchor isn't a Prawn option; we have to do some math to support it
    # and so we handle this in Prawn::SVG::Interface#rewrite_call_arguments
    opts = {
      size:        computed_properties.numerical_font_size,
      style:       font && font.subfamily,
      text_anchor: computed_properties.text_anchor
    }

    spacing = computed_properties.letter_spacing
    spacing = spacing == 'normal' ? 0 : document.points(spacing)

    add_call_and_enter 'character_spacing', spacing

    source.children.each do |child|
      if child.node_type == :text
        text = child.value.strip.gsub(state.preserve_space ? /[\n\t]/ : /\s+/, " ")

        while text != ""
          opts[:at] = [@x_positions.first, @y_positions.first]

          if @x_positions.length > 1 || @y_positions.length > 1
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
        new_state.text_x_positions = @x_positions
        new_state.text_y_positions = @y_positions
        new_state.text_relative = @relative

        Prawn::SVG::Elements::Text.new(document, child, calls, new_state).process

        add_call 'restore'

      else
        warnings << "Unknown tag '#{child.name}' inside text tag; ignoring"
      end
    end

    # It's possible there was no text to render.  In that case, add a 'noop' so
    # character_spacing doesn't blow up when it finds it doesn't have a block to execute.
    add_call 'noop' if calls.empty?
  end

  private

  def select_font
    font_families = [computed_properties.font_family, document.fallback_font_name]
    font_style = :italic if computed_properties.font_style == 'italic'
    font_weight = Prawn::SVG::Font.weight_for_css_font_weight(computed_properties.font_weight)

    font_families.compact.each do |name|
      font = document.font_registry.load(name, font_weight, font_style)
      return font if font
    end

    warnings << "Font family '#{computed_properties.font_family}' style '#{computed_properties.font_style}' is not a known font, and the fallback font could not be found."
    nil
  end

  def apply_font(font)
    add_call 'font', font.name, style: font.subfamily
  end
end
