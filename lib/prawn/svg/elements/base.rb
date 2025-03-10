class Prawn::SVG::Elements::Base
  extend Forwardable

  include Prawn::SVG::Elements::CallDuplicator

  include Prawn::SVG::Calculators::Pixels

  include Prawn::SVG::Attributes::Transform
  include Prawn::SVG::Attributes::Opacity
  include Prawn::SVG::Attributes::ClipPath
  include Prawn::SVG::Attributes::Stroke
  include Prawn::SVG::Attributes::Space

  include Prawn::SVG::TransformParser

  PAINT_TYPES = %w[fill stroke].freeze
  COMMA_WSP_REGEXP = Prawn::SVG::Elements::COMMA_WSP_REGEXP
  SVG_NAMESPACE = 'http://www.w3.org/2000/svg'.freeze

  SkipElementQuietly = Class.new(StandardError)
  SkipElementError = Class.new(StandardError)
  MissingAttributesError = Class.new(SkipElementError)

  attr_reader :document, :source, :parent_calls, :base_calls, :state, :attributes, :properties
  attr_accessor :calls

  def_delegators :@document, :warnings
  def_delegator :@state, :computed_properties

  def initialize(document, source, parent_calls, state)
    @document = document
    @source = source
    @parent_calls = parent_calls
    @state = state
    @base_calls = @calls = []
    @attributes = {}
    @properties = Prawn::SVG::Properties.new

    if source && !state.inside_use
      id = source.attributes['id']
      id = id.strip if id

      document.elements_by_id[id] = self if id && id != ''
    end
  end

  def process
    extract_attributes_and_properties
    parse_and_apply
  end

  def parse_and_apply
    parse_standard_attributes
    parse

    apply_calls_from_standard_attributes
    apply

    process_child_elements if container?

    append_calls_to_parent unless computed_properties.display == 'none'
  rescue SkipElementQuietly
  rescue SkipElementError => e
    @document.warnings << e.message
  end

  def name
    @name ||= source ? source.name : '???'
  end

  protected

  def parse; end

  def apply; end

  def bounding_box; end

  def container?
    false
  end

  def drawable?
    !container?
  end

  def parse_standard_attributes
    parse_xml_space_attribute
  end

  def add_call(name, *arguments, **kwarguments)
    @calls << [name.to_s, arguments, kwarguments, []]
  end

  def add_call_and_enter(name, *arguments, **kwarguments)
    @calls << [name.to_s, arguments, kwarguments, []]
    @calls = @calls.last.last
  end

  def push_call_position
    @call_positions ||= []
    @call_positions << @calls
  end

  def pop_call_position
    @calls = @call_positions.pop
  end

  def append_calls_to_parent
    @parent_calls.concat(@base_calls)
  end

  def add_calls_from_element(other)
    @calls.concat duplicate_calls(other.base_calls)
  end

  def new_call_context_from_base
    old_calls = @calls
    @calls = @base_calls
    yield
    @calls = old_calls
  end

  def process_child_elements
    return unless source

    svg_child_elements.each do |elem|
      if (element_class = Prawn::SVG::Elements::TAG_CLASS_MAPPING[elem.name.to_sym])
        add_call 'save'

        child = element_class.new(@document, elem, @calls, state.dup)
        child.process

        add_call 'restore'
      else
        @document.warnings << "Unknown tag '#{elem.name}'; ignoring"
      end
    end
  end

  def svg_child_elements
    source.elements.select do |elem|
      # To be strict, we shouldn't treat namespace-less elements as SVG, but for
      # backwards compatibility, and because it doesn't hurt, we will.
      [SVG_NAMESPACE, ''].include?(elem.namespace)
    end
  end

  def apply_calls_from_standard_attributes
    parse_transform_attribute_and_call
    parse_opacity_attributes_and_call
    parse_clip_path_attribute_and_call
    apply_colors
    parse_stroke_attributes_and_call
    apply_drawing_call
  end

  def apply_drawing_call
    return if state.disable_drawing || !drawable?

    fill   = !computed_properties.fill.none? # rubocop:disable Style/InverseMethods
    stroke = !computed_properties.stroke.none? # rubocop:disable Style/InverseMethods

    if fill
      command = stroke ? 'fill_and_stroke' : 'fill'

      if computed_properties.fill_rule == 'evenodd'
        add_call_and_enter(command, fill_rule: :even_odd)
      else
        add_call_and_enter(command)
      end
    elsif stroke
      add_call_and_enter('stroke')
    else
      add_call_and_enter('end_path')
    end
  end

  def apply_colors
    PAINT_TYPES.each do |type|
      paint = properties.send(type)

      case paint
      when nil, 'inherit'
        next
      when Prawn::SVG::Paint
        color = paint.resolve(document.gradients, computed_properties.color, document.color_mode)

        case color
        when Prawn::SVG::Color::RGB, Prawn::SVG::Color::CMYK
          add_call "#{type}_color", color.value
        when Prawn::SVG::Elements::Gradient
          add_call 'svg:render_gradient', type.to_sym, **color.gradient_arguments(self)
        when nil
          nil
        else
          raise "Unknown resolved color type: #{color.inspect}"
        end
      else
        raise "Unknown paint type: #{paint.inspect}"
      end
    end
  end

  def extract_attributes_and_properties
    # Apply user agent stylesheet
    if %w[svg symbol image marker pattern foreignObject].include?(source.name)
      @properties.set('overflow', 'hidden')
    end

    # Apply presentation attributes, and set attributes that aren't presentation attributes
    source.attributes.each do |name, value|
      # Properties#set returns nil if it's not a recognised property name
      @properties.set(name, value) or @attributes[name] = value
    end

    # Apply stylesheet styles
    if (styles = document.element_styles[source])
      styles.each do |name, value, important|
        @properties.set(name, value, important: important)
      end
    end

    # Apply inline styles
    @properties.load_hash(parse_css_declarations(source.attributes['style'] || ''))

    state.computed_properties.compute_properties(@properties)
  end

  def parse_css_declarations(declarations)
    # copied from css_parser
    declarations
      .gsub(/(^\s*)|(\s*$)/, '')
      .split(/[;$]+/m)
      .each_with_object({}) do |decs, output|
        if (matches = decs.match(/\s*(.[^:]*)\s*:\s*(.[^;]*)\s*(;|\Z)/i))
          property, value, = matches.captures
          output[property.downcase] = value
        end
      end
  end

  def require_attributes(*names)
    missing_attrs = names - attributes.keys
    if missing_attrs.any?
      raise MissingAttributesError, "Must have attributes #{missing_attrs.join(', ')} on tag #{name}; skipping tag"
    end
  end

  def require_positive_value(*args)
    if args.any? { |arg| arg.nil? || arg <= 0 }
      raise SkipElementError, "Invalid attributes on tag #{name}; skipping tag"
    end
  end

  def extract_element_from_url_id_reference(value, expected_type = nil)
    case value
    when Prawn::SVG::FuncIRI
      element = document.elements_by_id[value.url[1..]] if value.url.start_with?('#')
      element if element && (expected_type.nil? || element.name == expected_type)
    end
  end

  def href_attribute
    attributes['xlink:href'] || attributes['href']
  end

  def overflow_hidden?
    ['hidden', 'scroll'].include?(computed_properties.overflow)
  end

  def stroke_width
    if computed_properties.stroke.none?
      0
    else
      pixels(properties.stroke_width) || 1.0
    end
  end

  def clone_element_source(source)
    new_source = source.dup
    document.element_styles[new_source] = document.element_styles[source]
    new_source
  end
end
