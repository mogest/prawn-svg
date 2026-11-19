class Prawn::SVG::Elements::Base
  extend Forwardable

  include Prawn::SVG::Elements::CallDuplicator
  include Prawn::SVG::Elements::BboxScaling

  include Prawn::SVG::Calculators::Pixels

  include Prawn::SVG::Attributes::Transform
  include Prawn::SVG::Attributes::Opacity
  include Prawn::SVG::Attributes::ClipPath
  include Prawn::SVG::Attributes::Mask
  include Prawn::SVG::Attributes::Stroke
  include Prawn::SVG::Attributes::Space

  include Prawn::SVG::TransformParser

  PAINT_TYPES = %w[fill stroke].freeze
  COMMA_WSP_REGEXP = Prawn::SVG::Elements::COMMA_WSP_REGEXP
  SVG_NAMESPACE = 'http://www.w3.org/2000/svg'.freeze

  SkipElementQuietly = Class.new(StandardError)

  class SkipElementError < StandardError
    attr_reader :category

    def initialize(message = nil, category = :invalid)
      super(message)
      @category = category
    end
  end

  MissingAttributesError = Class.new(SkipElementError)

  attr_reader :document, :source, :parent_calls, :base_calls, :state, :attributes, :properties
  attr_accessor :calls

  def_delegators :@document, :add_issue
  def_delegator :@state, :computed_properties

  def initialize(document, source, parent_calls, state)
    @document = document
    @source = source
    @parent_calls = parent_calls
    @state = state
    @base_calls = @calls = []
    @attributes = {}
    @properties = Prawn::SVG::Properties.new

    if source && add_to_elements_by_id? && !state.inside_use
      id = source.attributes['id']
      id = id.strip if id

      document.elements_by_id[id] = self if id && id != ''
    end
  end

  def process
    document.work_budget.record(source.children.length + 1)

    if (state.depth += 1) > Prawn::SVG::Document::MAX_ELEMENT_DEPTH
      add_issue(:invalid, 'elements are nested too deeply')
      return
    end

    report_unsupported_children
    extract_attributes_and_properties
    # An element whose conditions fail isn't rendered, but can still be referenced.
    set_display_none unless passes_conditional_processing?(source)
    parse_and_apply
  end

  def parse_and_apply
    parse_standard_attributes
    parse

    apply_calls_from_standard_attributes
    apply

    if state.anchor_href && bounding_box
      add_call('svg:add_link', state.anchor_href, bounding_box)
    end

    process_child_elements if container?

    append_calls_to_parent unless computed_properties.display == 'none'
  rescue SkipElementQuietly
  rescue SkipElementError => e
    @document.add_issue(e.category, e.message)
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
    document.work_budget.record(call_work(name, kwarguments))
    @calls << [name.to_s, arguments, kwarguments, []]
  end

  def add_call_and_enter(name, *arguments, **kwarguments)
    document.work_budget.record(call_work(name, kwarguments))
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

  # Text adds these while it's drawn, when the work budget must no longer be charged.
  def add_yield_call(&block)
    @calls << ['svg:yield', [block], {}, []]
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
      elsif !Prawn::SVG::Elements::REPORTED_BY_PARENT_ELEMENTS.include?(elem.name)
        @document.add_issue(:unknown, "Unknown tag '#{elem.name}'; ignoring")
      end
    end
  end

  def report_unsupported_children
    svg_child_elements.each do |elem|
      if Prawn::SVG::Elements::REPORTED_BY_PARENT_ELEMENTS.include?(elem.name)
        @document.add_issue(:unsupported, "Unsupported tag '#{elem.name}'; ignoring")
      end
    end
  end

  # REXML's Element#elements re-parses an XPath on every call, so filter children directly.
  def svg_child_elements
    @svg_child_elements ||= source.children.select { |node| node.is_a?(REXML::Element) && svg_element?(node) }
  end

  def passes_conditional_processing?(element)
    return true unless Prawn::SVG::Elements::CONDITIONAL_PROCESSING_ELEMENTS.include?(element.name)

    passes_required_features?(element) &&
      element.attributes['requiredExtensions'].nil? &&
      passes_system_language?(element)
  end

  def passes_required_features?(element)
    value = element.attributes['requiredFeatures']
    return true if value.nil?

    features = value.split
    features.any? && features.all? { |feature| Prawn::SVG::Elements::SUPPORTED_FEATURES.include?(feature) }
  end

  def passes_system_language?(element)
    value = element.attributes['systemLanguage']
    return true if value.nil?

    user_language = document.language.downcase
    value.split(',').map { |lang| lang.strip.downcase }.any? do |lang|
      user_language == lang || lang.start_with?("#{user_language}-")
    end
  end

  # To be strict, we shouldn't treat namespace-less elements as SVG, but for backwards compatibility, and because it
  # doesn't hurt, we will.  REXML's Element#namespace takes time proportional to the square of the element's depth,
  # so look for the declaration ourselves.
  def svg_element?(elem)
    declaration = elem.prefix.empty? ? 'xmlns' : "xmlns:#{elem.prefix}"
    node = elem
    while node.is_a?(REXML::Element)
      node.attributes.each_attribute do |attribute|
        return [SVG_NAMESPACE, ''].include?(attribute.value) if attribute.expanded_name == declaration
      end
      node = node.parent
    end
    elem.prefix.empty?
  end

  def apply_calls_from_standard_attributes
    parse_transform_attribute_and_call
    parse_opacity_attributes_and_call
    parse_clip_path_attribute_and_call
    parse_mask_attribute_and_call
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
        when Prawn::SVG::Elements::Pattern
          args = color.pattern_arguments(self)
          add_call 'svg:render_pattern', type.to_sym, **args if args
        when nil
          add_issue(:invalid, "Could not resolve #{type} URI to a gradient or pattern element") if paint.color.nil?
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
      if Prawn::SVG::Properties.known?(name) || Prawn::SVG::Properties::OTHER_PRESENTATION_ATTRIBUTES.include?(name)
        set_property(name, value)
      else
        @attributes[name] = value
        if (category = attribute_issue_category(name, value))
          add_source_issue(category, "#{category.to_s.capitalize} attribute '#{name}' on <#{self.name}>")
        elsif (type = attribute_type(name)) && !Prawn::SVG::AttributeValue.valid?(type, value)
          add_source_issue(:invalid, "Invalid value '#{value.strip}' for attribute '#{name}' on <#{self.name}>")
        end
      end
    end

    # Apply stylesheet styles
    document.element_styles[source]&.each do |name, value, important|
      set_property(name, value, important: important)
    end

    # Apply inline styles
    parse_css_declarations(source.attributes['style'] || '').each do |name, value, important|
      set_property(name, value, important: important)
    end

    state.computed_properties.compute_properties(@properties)
  end

  def set_property(property, value, important: false)
    @properties.set(property, value, important: important).tap do |result|
      case result
      when nil
        if (category = Prawn::SVG::Properties.issue_category(property, value))
          add_source_issue(category, "#{category.to_s.capitalize} property '#{property}' on <#{name}>")
        end
      when false
        add_source_issue(:invalid, "Invalid value '#{value.strip}' for property '#{property}' on <#{name}>")
      end
    end
  end

  def attribute_issue_category(attribute, value)
    elements = Prawn::SVG::Elements
    supported = elements::ATTRIBUTES[name.to_sym] or return

    return if supported.include?(attribute) ||
              elements::GLOBAL_ATTRIBUTES.include?(attribute) ||
              (elements::CONDITIONAL_PROCESSING_ATTRIBUTES.include?(attribute) &&
                elements::CONDITIONAL_PROCESSING_ELEMENTS.include?(name)) ||
              elements::NO_EFFECT_ATTRIBUTES.include?(attribute) ||
              attribute.start_with?(*elements::NO_EFFECT_ATTRIBUTE_PREFIXES) ||
              attribute.include?(':')

    if elements::UNSUPPORTED_ATTRIBUTES.fetch(name.to_sym, []).include?(attribute)
      :unsupported unless elements::UNSUPPORTED_ATTRIBUTE_DEFAULTS[attribute] == value.strip
    else
      :unknown
    end
  end

  def attribute_type(attribute)
    elements = Prawn::SVG::Elements
    return unless elements::ATTRIBUTES.fetch(name.to_sym, []).include?(attribute)

    elements::ATTRIBUTE_TYPE_OVERRIDES.dig(name.to_sym, attribute.to_sym) || elements::ATTRIBUTE_TYPES[attribute.to_sym]
  end

  def add_source_issue(category, message)
    add_issue(category, message)
  end

  def parse_css_declarations(declarations)
    declarations.scan(/(?:"[^"]*"|'[^']*'|\([^)]*\)?|[^;"'(])+/).filter_map do |declaration|
      property, value = declaration.split(':', 2)
      property = property.strip.downcase
      next if value.nil? || property.empty?

      important = value.sub!(/!\s*important\s*\z/i, '')
      [property, value.strip, !important.nil?]
    end
  end

  def require_attributes(*names)
    missing_attrs = names - attributes.keys
    if missing_attrs.any?
      raise MissingAttributesError, "Must have attributes #{missing_attrs.join(', ')} on tag #{name}; skipping tag"
    end
  end

  # A zero size is valid and disables rendering of the element
  def require_positive_value(*args)
    if args.any? { |arg| arg.nil? || arg.negative? }
      raise SkipElementError, "Invalid attributes on tag #{name}; skipping tag"
    end

    raise SkipElementQuietly if args.any?(&:zero?)
  end

  def extract_element_from_url_id_reference(value, expected_type, property)
    return unless value.is_a?(Prawn::SVG::FuncIRI)

    id = value.url[1..] if value.url.start_with?('#')
    element = document.elements_by_id[id] if id
    return element if element&.name == expected_type

    if document.find_raw_element_by_id(id)&.name == expected_type
      add_issue(:unsupported, "Unsupported #{property} reference to a #{expected_type} that is defined later or not rendered")
    else
      add_issue(:invalid, "Could not resolve #{property} URI to a #{expected_type} element")
    end
    nil
  end

  def href_attribute
    attributes['xlink:href'] || attributes['href']
  end

  def overflow_hidden?
    ['hidden', 'scroll'].include?(computed_properties.overflow)
  end

  def transformable?
    true
  end

  def add_to_elements_by_id?
    true
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

  def set_display_none
    properties.display = 'none'
    computed_properties.display = 'none'
  end
end
