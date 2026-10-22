module Prawn::SVG::Elements
  COMMA_WSP_REGEXP = /(?:\s+,?\s*|,\s*)/.freeze
end

require 'prawn/svg/elements/call_duplicator'
require 'prawn/svg/elements/bbox_scaling'

%w[base direct_render_base root anchor container switch clip_path mask viewport text text_component text_node text_path line polyline polygon circle ellipse
   rect path use image gradient pattern marker ignored unsupported].each do |filename|
  require "prawn/svg/elements/#{filename}"
end

module Prawn::SVG::Elements
  # Unsupported, and reported by their parent, as they can be children of shapes, which don't process their children.
  # Not in TAG_CLASS_MAPPING, so <switch> doesn't select them.
  REPORTED_BY_PARENT_ELEMENTS = %w[animate animateColor animateMotion animateTransform set script].freeze

  TAG_CLASS_MAPPING = {
    g:              Prawn::SVG::Elements::Container,
    symbol:         Prawn::SVG::Elements::Container,
    defs:           Prawn::SVG::Elements::Container,
    a:              Prawn::SVG::Elements::Anchor,
    clipPath:       Prawn::SVG::Elements::ClipPath,
    switch:         Prawn::SVG::Elements::Switch,
    svg:            Prawn::SVG::Elements::Viewport,
    text:           Prawn::SVG::Elements::Text,
    line:           Prawn::SVG::Elements::Line,
    polyline:       Prawn::SVG::Elements::Polyline,
    polygon:        Prawn::SVG::Elements::Polygon,
    circle:         Prawn::SVG::Elements::Circle,
    ellipse:        Prawn::SVG::Elements::Ellipse,
    rect:           Prawn::SVG::Elements::Rect,
    path:           Prawn::SVG::Elements::Path,
    use:            Prawn::SVG::Elements::Use,
    image:          Prawn::SVG::Elements::Image,
    linearGradient: Prawn::SVG::Elements::Gradient,
    radialGradient: Prawn::SVG::Elements::Gradient,
    pattern:        Prawn::SVG::Elements::Pattern,
    marker:         Prawn::SVG::Elements::Marker,
    style:          Prawn::SVG::Elements::Ignored, # because it is pre-parsed by Document
    title:          Prawn::SVG::Elements::Ignored,
    desc:           Prawn::SVG::Elements::Ignored,
    metadata:       Prawn::SVG::Elements::Ignored,
    foreignObject:  Prawn::SVG::Elements::Unsupported,
    'font-face':    Prawn::SVG::Elements::Ignored,
    filter:         Prawn::SVG::Elements::Ignored, # the filter property is reported instead
    mask:           Prawn::SVG::Elements::Mask,
    view:           Prawn::SVG::Elements::Ignored
  }.freeze

  # Attributes supported on each element, excluding presentation attributes, which are handled by Properties.
  # Namespaced attributes such as xlink:href are never reported, so aren't listed.
  ATTRIBUTES = {
    svg:            %w[x y width height viewBox preserveAspectRatio transform],
    symbol:         %w[x y width height viewBox preserveAspectRatio],
    g:              %w[transform],
    defs:           %w[transform],
    a:              %w[href transform],
    switch:         %w[transform],
    clipPath:       %w[clipPathUnits transform],
    mask:           %w[x y width height maskUnits maskContentUnits],
    marker:         %w[markerWidth markerHeight markerUnits orient refX refY viewBox preserveAspectRatio],
    pattern:        %w[x y width height patternUnits patternContentUnits patternTransform viewBox preserveAspectRatio href],
    linearGradient: %w[x1 y1 x2 y2 gradientUnits gradientTransform spreadMethod href],
    radialGradient: %w[cx cy r fx fy fr gradientUnits gradientTransform spreadMethod href],
    stop:           %w[offset],
    text:           %w[x y dx dy rotate textLength lengthAdjust transform],
    tspan:          %w[x y dx dy rotate textLength lengthAdjust],
    tref:           %w[x y dx dy rotate textLength lengthAdjust href],
    textPath:       %w[startOffset textLength lengthAdjust href],
    line:           %w[x1 y1 x2 y2 transform],
    polyline:       %w[points transform],
    polygon:        %w[points transform],
    circle:         %w[cx cy r transform],
    ellipse:        %w[cx cy rx ry transform],
    rect:           %w[x y width height rx ry transform],
    path:           %w[d transform],
    use:            %w[x y width height href transform],
    image:          %w[x y width height preserveAspectRatio href transform]
  }.freeze

  UNITS_VALUES = %w[userSpaceOnUse objectBoundingBox].freeze

  # Types of attribute values, checked by AttributeValue.valid?.  Attributes not listed aren't checked.
  ATTRIBUTE_TYPES = {
    x: :length, y: :length, width: :length, height: :length,
    x1: :length, y1: :length, x2: :length, y2: :length,
    cx: :length, cy: :length, r: :length, rx: :length, ry: :length, fx: :length, fy: :length, fr: :length,
    refX: :length, refY: :length, markerWidth: :length, markerHeight: :length,
    textLength: :length, startOffset: :length,
    dx: :length_list, dy: :length_list, rotate: :number_list,
    offset: :number_or_percentage,
    viewBox: :view_box, preserveAspectRatio: :preserve_aspect_ratio, orient: :orient,
    gradientUnits: UNITS_VALUES, patternUnits: UNITS_VALUES, patternContentUnits: UNITS_VALUES,
    clipPathUnits: UNITS_VALUES, maskUnits: UNITS_VALUES, maskContentUnits: UNITS_VALUES,
    markerUnits: %w[strokeWidth userSpaceOnUse],
    spreadMethod: %w[pad reflect repeat],
    lengthAdjust: %w[spacing spacingAndGlyphs]
  }.freeze

  ATTRIBUTE_TYPE_OVERRIDES = {
    text:  { x: :length_list, y: :length_list },
    tspan: { x: :length_list, y: :length_list },
    tref:  { x: :length_list, y: :length_list }
  }.freeze

  GLOBAL_ATTRIBUTES = %w[id class style].freeze

  # Attributes that are valid but have no effect on a static rendering
  NO_EFFECT_ATTRIBUTES = %w[
    version baseProfile lang role tabindex focusable autofocus nonce target requiredFeatures
    contentScriptType contentStyleType zoomAndPan externalResourcesRequired
    crossorigin decoding rel download hreflang type referrerpolicy ping
  ].freeze

  # 'on' covers event handlers
  NO_EFFECT_ATTRIBUTE_PREFIXES = %w[xmlns data- aria- on].freeze

  # Valid attributes that prawn-svg doesn't support
  UNSUPPORTED_ATTRIBUTES = {
    path:     %w[pathLength],
    rect:     %w[pathLength],
    circle:   %w[pathLength],
    ellipse:  %w[pathLength],
    line:     %w[pathLength],
    polyline: %w[pathLength],
    polygon:  %w[pathLength],
    symbol:   %w[refX refY],
    textPath: %w[method spacing side path]
  }.freeze

  # Only evaluated by <switch>, on its children
  CONDITIONAL_ATTRIBUTES = %w[systemLanguage requiredExtensions].freeze
end
