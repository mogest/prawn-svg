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
      state[:ids][id] = @base_calls
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
  
  
  protected
  def apply_styles
    # Transform
    if transform = @attributes['transform']
      parse_css_method_calls(transform).each do |name, arguments|
        case name
        when 'translate'
          x, y = arguments
          x, y = x.split(/\s+/) if y.nil?
          add_call_and_enter name, @document.distance(x), -@document.distance(y)

        when 'rotate'
          rotation_arguments = arguments.first.split(/\s+/)
          if (rotation_arguments.length == 3)
            add_call_and_enter name, -rotation_arguments.first.to_f, :origin => [@document.x(rotation_arguments[1].to_f), @document.y(rotation_arguments[2].to_f)]
          else
            add_call_and_enter name, -arguments.first.to_f, :origin => [0, @document.y('0')]
          end

        when 'scale'
          args = arguments.first.split(/\s+/)
          x_scale = args[0].to_f
          y_scale = (args[1] || x_scale).to_f
          add_call_and_enter "transformation_matrix", x_scale, 0, 0, y_scale, 0, 0

        when 'matrix'
          args = arguments.first.split(/\s+/)
          if args.length != 6
            @document.warnings << "transform 'matrix' must have six arguments"
          else
            a, b, c, d, e, f = args.collect {|a| a.to_f}
            add_call_and_enter "transformation_matrix", a, b, c, d, @document.distance(e), -@document.distance(f)
          end
        else
          @document.warnings << "Unknown transformation '#{name}'; ignoring"
        end
      end
    end    
        
    # Opacity:
    # We can't do nested opacities quite like the SVG requires, but this is close enough.
    fill_opacity = stroke_opacity = clamp(@attributes['opacity'].to_f, 0, 1) if @attributes['opacity']
    fill_opacity = clamp(@attributes['fill-opacity'].to_f, 0, 1) if @attributes['fill-opacity']
    stroke_opacity = clamp(@attributes['stroke-opacity'].to_f, 0, 1) if @attributes['stroke-opacity']

    if fill_opacity || stroke_opacity      
      state[:fill_opacity] = (state[:fill_opacity] || 1) * (fill_opacity || 1)
      state[:stroke_opacity] = (state[:stroke_opacity] || 1) * (stroke_opacity || 1)

      add_call_and_enter 'transparent', state[:fill_opacity], state[:stroke_opacity]
    end

    # Fill and stroke
    draw_types = []  
    [:fill, :stroke].each do |type|
      dec = @attributes[type.to_s]
      if dec == "none"
        state[type] = false
      elsif dec
        state[type] = true
        if color = color_to_hex(dec)
          add_call "#{type}_color", color
        end
      end

      draw_types << type.to_s if state[type]
    end
    
    # Stroke width
    add_call('line_width', @document.distance(@attributes['stroke-width'])) if @attributes['stroke-width']      

    # Fonts        
    if size = @attributes['font-size']
      @state[:font_size] = size.to_f * @document.scale
    end
    if weight = @attributes['font-weight']
      font_updated = true
      @state[:font_style] = weight == 'bold' ? :bold : nil
    end
    if (family = @attributes['font-family']) && family.strip != ""
      font_updated = true
      @state[:font_family] = family
    end
    
    if @state[:font_family] && font_updated
      if pdf_font = Prawn::Svg::Font.map_font_family_to_pdf_font(@state[:font_family], @state[:font_style])
        add_call_and_enter 'font', pdf_font
      else
        @document.warnings << "Font family '#{@state[:font_family]}' style '#{@state[:font_style] || 'normal'}' is not a known font."
      end
    end    
    
    # Call fill, stroke, or both
    draw_type = draw_types.join("_and_")
    if draw_type != "" && !Prawn::Svg::Parser::CONTAINER_TAGS.include?(element.name)
      add_call_and_enter draw_type
    end            
  end

  def parse_css_method_calls(string)
    string.scan(/\s*(\w+)\(([^)]+)\)\s*/).collect do |call|
      name, argument_string = call
      arguments = argument_string.split(",").collect {|s| s.strip}
      [name, arguments]
    end    
  end

  # TODO : use http://www.w3.org/TR/SVG11/types.html#ColorKeywords
  HTML_COLORS = {    
  	'black' => "000000", 'green' => "008000", 'silver' => "c0c0c0", 'lime' => "00ff00",
  	'gray' => "808080", 'olive' => "808000", 'white' => "ffffff", 'yellow' => "ffff00",
  	'maroon' => "800000", 'navy' => "000080", 'red' => "ff0000", 'blue' => "0000ff",
  	'purple' => "800080", 'teal' => "008080", 'fuchsia' => "ff00ff", 'aqua' => "00ffff"
  }.freeze

  RGB_VALUE_REGEXP = "\s*(-?[0-9.]+%?)\s*"
  RGB_REGEXP = /\Argb\(#{RGB_VALUE_REGEXP},#{RGB_VALUE_REGEXP},#{RGB_VALUE_REGEXP}\)\z/i

  def color_to_hex(color_string)
    color_string.scan(/([^(\s]+(\([^)]*\))?)/).detect do |color, *_|
      if m = color.match(/\A#([0-9a-f])([0-9a-f])([0-9a-f])\z/i)
        break "#{m[1] * 2}#{m[2] * 2}#{m[3] * 2}"
      elsif color.match(/\A#[0-9a-f]{6}\z/i)
        break color[1..6]
      elsif hex = HTML_COLORS[color.downcase]
        break hex
      elsif m = color.match(RGB_REGEXP)
        break (1..3).collect do |n|
          value = m[n].to_f
          value *= 2.55 if m[n][-1..-1] == '%'
          "%02x" % clamp(value.round, 0, 255)
        end.join        
      end    
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
