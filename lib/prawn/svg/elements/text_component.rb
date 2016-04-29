class Prawn::SVG::Elements::TextComponent < Prawn::SVG::Elements::DepthFirstBase
  attr_reader :commands, :text_state

  Printable = Struct.new(:element, :text, :leading_space?, :trailing_space?)

  def parse
    @x = attributes['x'].split(COMMA_WSP_REGEXP).collect {|n| x(n)} if attributes['x']
    @y = attributes['y'].split(COMMA_WSP_REGEXP).collect {|n| y(n)} if attributes['y']

    @commands = []

    text_children.each do |child|
      if child.node_type == :text
        append_text(child)
      else
        case child.name
        when 'tspan', 'tref'
          append_child(child)
        else
          warnings << "Unknown tag '#{child.name}' inside text tag; ignoring"
        end
      end
    end
  end

  def apply
    raise SkipElementQuietly if computed_properties.display == "none"

    @text_state = state.text

    if @x || @y
      text_state.relative = false
      text_state.x_positions = @x if @x
      text_state.y_positions = @y if @y
    end

    text_state.x_positions ||= [x(0)]
    text_state.y_positions ||= [y(0)]

    font = select_font
    apply_font(font) if font

    if attributes['dx'] || attributes['dy']
      add_call_and_enter "translate", x_pixels(attributes['dx'] || 0), -y_pixels(attributes['dy'] || 0)
    end

    # text_anchor isn't a Prawn option; we have to do some math to support it
    # and so we handle this in Prawn::SVG::Interface#rewrite_call_arguments
    opts = {
      size:        computed_properties.numerical_font_size,
      style:       font && font.subfamily,
      text_anchor: computed_properties.text_anchor
    }

    spacing = computed_properties.letter_spacing
    spacing = spacing == 'normal' ? 0 : pixels(spacing)

    add_call_and_enter 'character_spacing', spacing

    @commands.each do |command|
      case command
      when Printable
        apply_text(command.text, opts)
      when self.class
        add_call 'save'
        command.apply_step(calls)
        add_call 'restore'
      else
        raise
      end
    end

    # It's possible there was no text to render.  In that case, add a 'noop' so
    # character_spacing doesn't blow up when it finds it doesn't have a block to execute.
    add_call 'noop' if calls.empty?
  end

  protected

  def append_text(child)
    if state.preserve_space
      text = child.value.tr("\n\t", ' ')
    else
      text = child.value.tr("\n", '').tr("\t", ' ')
      leading = text[0] == ' '
      trailing = text[-1] == ' '
      text = text.strip.gsub(/ {2,}/, ' ')
    end

    @commands << Printable.new(self, text, leading, trailing)
  end

  def append_child(child)
    element = self.class.new(document, child, calls, state.dup)
    @commands << element
    element.parse_step
  end

  def apply_text(text, opts)
    while text != ""
      opts[:at] = [text_state.x_positions.first, text_state.y_positions.first]

      multiple_x_positions = text_state.x_positions.length > 1
      multiple_y_positions = text_state.y_positions.length > 1
      multiple_positions   = multiple_x_positions || multiple_y_positions

      opts[:relative] = true if text_state.relative
      text_state.relative = !multiple_positions

      if multiple_positions
        add_call 'draw_text', text[0..0], opts.dup
        text = text[1..-1]

        text_state.x_positions.shift if multiple_x_positions
        text_state.y_positions.shift if multiple_y_positions
      else
        add_call 'draw_text', text, opts.dup
        text_state.relative = true
        break
      end
    end
  end

  def text_children
    if name == 'tref'
      reference = find_referenced_element
      reference ? reference.source.children : []
    else
      source.children
    end
  end

  def find_referenced_element
    href = attributes['xlink:href']

    if href && href[0..0] == '#'
      element = document.elements_by_id[href[1..-1]]
      element if element.name == 'text'
    end
  end

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
