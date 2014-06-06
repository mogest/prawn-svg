class Prawn::Svg::Element
  attr_reader :document, :element, :parent_calls, :base_calls, :state, :attributes
  attr_accessor :calls

  def initialize(document, element, parent_calls, state)
    @document = document
    @element = element
    @parent_calls = parent_calls
    @state = state
    @base_calls = @calls = []

    combine_attributes_and_style_declarations
    apply_styles

    if id = @attributes["id"]
      document.elements_by_id[id] = self
    end
  end

  def name
    @name ||= element.name
  end

  def each_child_element
    element.elements.each do |e|
      yield self.class.new(@document, e, @calls, @state.dup)
    end
  end

  def warnings
    @document.warnings
  end

  def add_call(name, *arguments)
    @calls << [name.to_s, arguments, []]
  end

  def add_call_and_enter(name, *arguments)
    @calls << [name.to_s, arguments, []]
    @calls = @calls.last.last
  end

  def append_calls_to_parent
    @parent_calls.concat(@base_calls)
  end

  def add_calls_from_element(other)
    @calls.concat other.base_calls
  end


  protected
  def apply_styles
    parse_transform_attribute_and_call
    parse_opacity_attributes_and_call
    parse_clip_path_attribute_and_call
    draw_types = parse_fill_and_stroke_attributes_and_call
    parse_stroke_width_attribute_and_call
    parse_font_attributes_and_call
    apply_drawing_call(draw_types)
  end

  def apply_drawing_call(draw_types)
    if !@state[:disable_drawing] && !container?
      if draw_types.empty?
        add_call_and_enter("end_path")
      else
        add_call_and_enter(draw_types.join("_and_"))
      end
    end
  end

  def container?
    Prawn::Svg::Parser::CONTAINER_TAGS.include?(name)
  end

  def parse_transform_attribute_and_call
    return unless transform = @attributes['transform']

    parse_css_method_calls(transform).each do |name, arguments|
      case name
      when 'translate'
        x, y = arguments
        add_call_and_enter name, @document.distance(x), -@document.distance(y)

      when 'rotate'
        r, x, y = arguments.collect {|a| a.to_f}
        if arguments.length == 3
          add_call_and_enter name, -r, :origin => [@document.x(x), @document.y(y)]
        else
          add_call_and_enter name, -r, :origin => [0, @document.y('0')]
        end

      when 'scale'
        x_scale = arguments[0].to_f
        y_scale = (arguments[1] || x_scale).to_f
        add_call_and_enter "transformation_matrix", x_scale, 0, 0, y_scale, 0, 0

      when 'matrix'
        if arguments.length != 6
          @document.warnings << "transform 'matrix' must have six arguments"
        else
          a, b, c, d, e, f = arguments.collect {|argument| argument.to_f}
          add_call_and_enter "transformation_matrix", a, -b, -c, d, @document.distance(e), -@document.distance(f)
        end
      else
        @document.warnings << "Unknown transformation '#{name}'; ignoring"
      end
    end
  end

  def parse_opacity_attributes_and_call
    # We can't do nested opacities quite like the SVG requires, but this is close enough.
    fill_opacity = stroke_opacity = clamp(@attributes['opacity'].to_f, 0, 1) if @attributes['opacity']
    fill_opacity = clamp(@attributes['fill-opacity'].to_f, 0, 1) if @attributes['fill-opacity']
    stroke_opacity = clamp(@attributes['stroke-opacity'].to_f, 0, 1) if @attributes['stroke-opacity']

    if fill_opacity || stroke_opacity
      state[:fill_opacity] = (state[:fill_opacity] || 1) * (fill_opacity || 1)
      state[:stroke_opacity] = (state[:stroke_opacity] || 1) * (stroke_opacity || 1)

      add_call_and_enter 'transparent', state[:fill_opacity], state[:stroke_opacity]
    end
  end

  def parse_clip_path_attribute_and_call
    return unless clip_path = @attributes['clip-path']

    if (matches = clip_path.strip.match(/\Aurl\(#(.*)\)\z/)).nil?
      document.warnings << "Only clip-path attributes with the form 'url(#xxx)' are supported"
    elsif (clip_path_element = @document.elements_by_id[matches[1]]).nil?
      document.warnings << "clip-path ID '#{matches[1]}' not defined"
    elsif clip_path_element.element.name != "clipPath"
      document.warnings << "clip-path ID '#{matches[1]}' does not point to a clipPath tag"
    else
      add_call_and_enter 'save_graphics_state'
      add_calls_from_element clip_path_element
      add_call "clip"
    end
  end

  def parse_fill_and_stroke_attributes_and_call
    ["fill", "stroke"].select do |type|
      dec = @attributes[type]
      if dec == "none"
        state[type.to_sym] = false
      elsif dec
        state[type.to_sym] = true
        if color = Prawn::Svg::Color.color_to_hex(dec)
          add_call "#{type}_color", color
        end
      end

      state[type.to_sym]
    end
  end

  def parse_stroke_width_attribute_and_call
    add_call('line_width', @document.distance(@attributes['stroke-width'])) if @attributes['stroke-width']
  end

  def parse_font_attributes_and_call
    if size = @attributes['font-size']
      @state[:font_size] = size.to_f
    end
    if weight = @attributes['font-weight']
      font_updated = true
      @state[:font_weight] = Prawn::Svg::Font.weight_for_css_font_weight(weight)
    end
    if style = @attributes['font-style']
      font_updated = true
      @state[:font_style] = style == 'italic' ? :italic : nil
    end
    if (family = @attributes['font-family']) && family.strip != ""
      font_updated = true
      @state[:font_family] = family
    end

    if @state[:font_family] && font_updated
      usable_font_families = [@state[:font_family], document.fallback_font_name]

      font_used = usable_font_families.compact.detect do |name|
        if font = Prawn::Svg::Font.load(name, @state[:font_weight], @state[:font_style])
          @state[:font_subfamily] = font.subfamily
          add_call_and_enter 'font', font.name, :style => @state[:font_subfamily]
          true
        end
      end

      if font_used.nil?
        @document.warnings << "Font family '#{@state[:font_family]}' style '#{@state[:font_style] || 'normal'}' is not a known font, and the fallback font could not be found."
      end
    end
  end


  def parse_css_method_calls(string)
    string.scan(/\s*(\w+)\(([^)]+)\)\s*/).collect do |call|
      name, argument_string = call
      arguments = argument_string.strip.split(/\s*[,\s]\s*/)
      [name, arguments]
    end
  end

  def clamp(value, min_value, max_value)
    [[value, min_value].max, max_value].min
  end

  def combine_attributes_and_style_declarations
    if @document && @document.css_parser
      tag_style = @document.css_parser.find_by_selector(element.name)
      id_style = @document.css_parser.find_by_selector("##{element.attributes["id"]}") if element.attributes["id"]

      if classes = element.attributes["class"]
        class_styles = classes.strip.split(/\s+/).collect do |class_name|
          @document.css_parser.find_by_selector(".#{class_name}")
        end
      end

      element_style = element.attributes['style']

      style = [tag_style, class_styles, id_style, element_style].flatten.collect do |s|
        s.nil? || s.strip == "" ? "" : "#{s}#{";" unless s.match(/;\s*\z/)}"
      end.join
    else
      style = element.attributes['style'] || ""
    end

    @attributes = parse_css_declarations(style)
    element.attributes.each {|n,v| @attributes[n] = v unless @attributes[n]}
  end

  def parse_css_declarations(declarations)
    # copied from css_parser
    declarations.gsub!(/(^[\s]*)|([\s]*$)/, '')

    output = {}
    declarations.split(/[\;$]+/m).each do |decs|
      if matches = decs.match(/\s*(.[^:]*)\s*\:\s*(.[^;]*)\s*(;|\Z)/i)
        property, value, end_of_declaration = matches.captures
        output[property] = value
      end
    end
    output
  end
end
