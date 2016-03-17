class Prawn::SVG::Elements::Base
  extend Forwardable

  include Prawn::SVG::Attributes::Transform
  include Prawn::SVG::Attributes::Opacity
  include Prawn::SVG::Attributes::ClipPath
  include Prawn::SVG::Attributes::Stroke
  include Prawn::SVG::Attributes::Font
  include Prawn::SVG::Attributes::Display
  include Prawn::SVG::Attributes::Color

  COMMA_WSP_REGEXP = Prawn::SVG::Elements::COMMA_WSP_REGEXP

  SkipElementQuietly = Class.new(StandardError)
  SkipElementError = Class.new(StandardError)
  MissingAttributesError = Class.new(SkipElementError)

  attr_reader :document, :source, :parent_calls, :base_calls, :state, :attributes
  attr_accessor :calls

  def_delegators :@document, :x, :y, :distance, :points, :warnings

  def initialize(document, source, parent_calls, state)
    @document = document
    @source = source
    @parent_calls = parent_calls
    @state = state
    @base_calls = @calls = []

    if id = source.attributes["id"]
      document.elements_by_id[id] = self
    end
  end

  def process
    combine_attributes_and_style_declarations
    parse_standard_attributes
    parse

    apply_calls_from_standard_attributes
    apply

    append_calls_to_parent
  rescue SkipElementQuietly
  rescue SkipElementError => e
    @document.warnings << e.message
  end

  def name
    @name ||= source.name
  end

  protected

  def parse
  end

  def apply
  end

  def bounding_box
  end

  def container?
    false
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

  def process_child_elements
    source.elements.each do |elem|
      if element_class = Prawn::SVG::Elements::TAG_CLASS_MAPPING[elem.name.to_sym]
        add_call "save"

        child = element_class.new(@document, elem, @calls, @state.dup)
        child.process

        add_call "restore"
      else
        @document.warnings << "Unknown tag '#{elem.name}'; ignoring"
      end
    end
  end

  def apply_calls_from_standard_attributes
    parse_transform_attribute_and_call
    parse_opacity_attributes_and_call
    parse_clip_path_attribute_and_call
    draw_types = parse_fill_and_stroke_attributes_and_call
    parse_stroke_attributes_and_call
    parse_font_attributes_and_call
    parse_display_attribute
    apply_drawing_call(draw_types)
  end

  def apply_drawing_call(draw_types)
    if !@state[:disable_drawing] && !container?
      if draw_types.empty? || @state[:display] == "none"
        add_call_and_enter("end_path")
      else
        add_call_and_enter(draw_types.join("_and_"))
      end
    end
  end

  def parse_standard_attributes
    parse_color_attribute
  end

  def parse_fill_and_stroke_attributes_and_call
    ["fill", "stroke"].select do |type|
      case keyword = attribute_value_as_keyword(type)
      when nil
      when 'inherit'
      when 'none'
        state[type.to_sym] = false
      else
        state[type.to_sym] = false

        if keyword == 'currentcolor'
          color = state[:color]
        else
          color = @attributes[type]
        end

        results = Prawn::SVG::Color.parse(color, document.gradients)

        results.each do |result|
          case result
          when Prawn::SVG::Color::Hex
            state[type.to_sym] = true
            add_call "#{type}_color", result.value
            break
          when Prawn::SVG::Elements::Gradient
            arguments = result.gradient_arguments(self)
            if arguments
              state[type.to_sym] = true
              add_call "#{type}_gradient", **arguments
              break
            end
          end
        end
      end

      state[type.to_sym]
    end
  end

  def clamp(value, min_value, max_value)
    [[value, min_value].max, max_value].min
  end

  def combine_attributes_and_style_declarations
    if @document && @document.css_parser
      tag_style = @document.css_parser.find_by_selector(source.name)
      id_style = @document.css_parser.find_by_selector("##{source.attributes["id"]}") if source.attributes["id"]

      if classes = source.attributes["class"]
        class_styles = classes.strip.split(/\s+/).collect do |class_name|
          @document.css_parser.find_by_selector(".#{class_name}")
        end
      end

      element_style = source.attributes['style']

      style = [tag_style, class_styles, id_style, element_style].flatten.collect do |s|
        s.nil? || s.strip == "" ? "" : "#{s}#{";" unless s.match(/;\s*\z/)}"
      end.join
    else
      style = source.attributes['style'] || ""
    end

    @attributes = parse_css_declarations(style)

    source.attributes.each do |name, value|
      name = name.downcase # TODO : this is incorrect; attributes are case sensitive
      @attributes[name] = value unless @attributes[name]
    end
  end

  def parse_css_declarations(declarations)
    # copied from css_parser
    declarations.gsub!(/(^[\s]*)|([\s]*$)/, '')

    output = {}
    declarations.split(/[\;$]+/m).each do |decs|
      if matches = decs.match(/\s*(.[^:]*)\s*\:\s*(.[^;]*)\s*(;|\Z)/i)
        property, value, _ = matches.captures
        output[property.downcase] = value
      end
    end
    output
  end

  def attribute_value_as_keyword(name)
    if value = @attributes[name]
      value.strip.downcase
    end
  end

  def parse_points(points_string)
    points_string.
      to_s.
      strip.
      gsub(/(\d)-(\d)/, '\1 -\2').
      split(COMMA_WSP_REGEXP).
      each_slice(2).
      map {|x, y| [x(x), y(y)]}
  end

  def require_attributes(*names)
    missing_attrs = names - attributes.keys
    if missing_attrs.any?
      raise MissingAttributesError, "Must have attributes #{missing_attrs.join(", ")} on tag #{name}; skipping tag"
    end
  end

  def require_positive_value(*args)
    if args.any? {|arg| arg.nil? || arg <= 0}
      raise SkipElementError, "Invalid attributes on tag #{name}; skipping tag"
    end
  end
end
