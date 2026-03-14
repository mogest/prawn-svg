class Prawn::SVG::Elements::Switch < Prawn::SVG::Elements::Base
  FEATURE_PREFIX = 'http://www.w3.org/TR/SVG11/feature#'.freeze

  SUPPORTED_FEATURES = Set.new(
    %w[
      SVG
      SVG-static
      CoreAttribute
      Structure
      BasicStructure
      ConditionalProcessing
      Image
      Style
      Shape
      Text
      BasicText
      PaintAttribute
      BasicPaintAttribute
      OpacityAttribute
      BasicGraphicsAttribute
      Marker
      Gradient
      Pattern
      Clip
      BasicClip
      Mask
      Hyperlinking
      XlinkAttribute
    ].map { |name| "#{FEATURE_PREFIX}#{name}" }
  ).freeze

  def container?
    true
  end

  def process_child_elements
    return unless source

    elem = svg_child_elements.find do |e|
      passes_conditional_processing?(e) && Prawn::SVG::Elements::TAG_CLASS_MAPPING[e.name.to_sym]
    end

    return unless elem

    element_class = Prawn::SVG::Elements::TAG_CLASS_MAPPING[elem.name.to_sym]
    add_call 'save'
    child = element_class.new(@document, elem, @calls, state.dup)
    child.process
    add_call 'restore'
  end

  private

  def passes_conditional_processing?(element)
    passes_required_features?(element) &&
      passes_required_extensions?(element) &&
      passes_system_language?(element)
  end

  def passes_required_features?(element)
    value = element.attributes['requiredFeatures']
    return true if value.nil?

    features = value.strip.split(/\s+/)
    return false if features.empty?

    features.all? { |feature| SUPPORTED_FEATURES.include?(feature) }
  end

  def passes_required_extensions?(element)
    value = element.attributes['requiredExtensions']
    return true if value.nil?

    # We don't support any extensions
    false
  end

  def passes_system_language?(element)
    value = element.attributes['systemLanguage']
    return true if value.nil?

    languages = value.strip.split(/\s*,\s*/)
    return false if languages.empty? || languages == ['']

    user_language = (document.instance_variable_get(:@options)[:language] || 'en').downcase

    languages.any? do |lang|
      lang = lang.strip.downcase
      user_language == lang || lang.start_with?("#{user_language}-")
    end
  end
end
