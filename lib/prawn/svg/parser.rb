require 'rexml/document'

#
# Prawn::Svg::Parser is responsible for parsing an SVG file and converting it into a tree of
# prawn-compatible method calls.
#
# You probably do not want to use this class directly.  Instead, use Prawn::Svg to draw
# SVG data to your Prawn::Document object.
#
# This class is not passed the prawn object, so knows nothing about
# prawn specifically - this might be useful if you want to take this code and use it to convert
# SVG to another format.
#
class Prawn::Svg::Parser
  CONTAINER_TAGS = %w(g svg symbol defs clipPath)
  COMMA_WSP_REGEXP = /(?:\s+,?\s*|,\s*)/

  #
  # Construct a Parser object.
  #
  # The +data+ argument is SVG data.
  #
  # +bounds+ is a tuple [width, height] that specifies the bounds of the drawing space in points.
  #
  # +options+ can optionally contain
  # the key :width or :height.  If both are specified, only :width will be used.
  #
  def initialize(document)
    @document = document
  end

  #
  # Parse the SVG data and return a call tree.  The returned +Array+ is in the format:
  #
  #   [
  #     ['prawn_method_name', ['argument1', 'argument2'], []],
  #     ['method_that_takes_a_block', ['argument1', 'argument2'], [
  #       ['method_called_inside_block', ['argument'], []]
  #     ]
  #   ]
  #
  def parse
    @document.warnings.clear

    calls = [['fill_color', '000000', []]]

    calls << [
      'transformation_matrix',
      [@document.sizing.x_scale, 0, 0, @document.sizing.y_scale, 0, 0],
      []
    ]

    calls << [
      'transformation_matrix',
      [1, 0, 0, 1, @document.sizing.x_offset, @document.sizing.y_offset],
      []
    ]

    root_element = Prawn::Svg::Element.new(@document, @document.root, calls, :ids => {}, :fill => true)

    parse_element(root_element)
    calls
  end


  private
  REQUIRED_ATTRIBUTES = {
    "polyline"  => %w(points),
    "polygon"   => %w(points),
    "circle"    => %w(r),
    "ellipse"   => %w(rx ry),
    "rect"      => %w(width height),
    "path"      => %w(d),
    "image"     => %w(width height)
  }

  USE_NEW_CIRCLE_CALL = Prawn::Document.new.respond_to?(:circle)
  USE_NEW_ELLIPSE_CALL = Prawn::Document.new.respond_to?(:ellipse)

  def parse_element(element)
    attrs = element.attributes

    if required_attributes = REQUIRED_ATTRIBUTES[element.name]
      return unless check_attrs_present(element, required_attributes)
    end

    case element.name
    when *CONTAINER_TAGS
      do_not_append_calls = %w(symbol defs clipPath).include?(element.name)
      element.state[:disable_drawing] = true if element.name == "clipPath"

      element.each_child_element do |child|
        element.add_call "save"
        parse_element(child)
        element.add_call "restore"
      end

    when 'style'
      load_css_styles(element)

    when 'text'
      @svg_text ||= Text.new
      @svg_text.parse(element)

    when 'line'
      element.add_call 'line', x(attrs['x1'] || '0'), y(attrs['y1'] || '0'), x(attrs['x2'] || '0'), y(attrs['y2'] || '0')

    when 'polyline'
      points = parse_points(attrs['points'])
      return unless points.length > 0
      x, y = points.shift
      element.add_call 'move_to', x(x), y(y)
      element.add_call_and_enter 'stroke'
      points.each do |x, y|
        element.add_call "line_to", x(x), y(y)
      end

    when 'polygon'
      points = parse_points(attrs['points']).collect do |x, y|
        [x(x), y(y)]
      end
      element.add_call "polygon", *points

    when 'circle'
      xy, r = [x(attrs['cx'] || "0"), y(attrs['cy'] || "0")], distance(attrs['r'])

      return if zero_argument?(r)

      if USE_NEW_CIRCLE_CALL
        element.add_call "circle", xy, r
      else
        element.add_call "circle_at", xy, :radius => r
      end

    when 'ellipse'
      xy, rx, ry = [x(attrs['cx'] || "0"), y(attrs['cy'] || "0")], distance(attrs['rx'], :x), distance(attrs['ry'], :y)

      return if zero_argument?(rx, ry)

      element.add_call USE_NEW_ELLIPSE_CALL ? "ellipse" : "ellipse_at", xy, rx, ry

    when 'rect'
      xy            = [x(attrs['x'] || '0'), y(attrs['y'] || '0')]
      width, height = distance(attrs['width'], :x), distance(attrs['height'], :y)
      radius        = distance(attrs['rx'] || attrs['ry'])

      return if zero_argument?(width, height)

      if radius
        # n.b. does not support both rx and ry being specified with different values
        element.add_call "rounded_rectangle", xy, width, height, radius
      else
        element.add_call "rectangle", xy, width, height
      end

    when 'path'
      parse_path(element)

    when 'use'
      parse_use(element)

    when 'title', 'desc', 'metadata'
      # ignore
      do_not_append_calls = true

    when 'font-face'
      # not supported
      do_not_append_calls = true

    when 'image'
      @svg_image ||= Image.new(@document)
      @svg_image.parse(element)

    else
      @document.warnings << "Unknown tag '#{element.name}'; ignoring"
    end

    element.append_calls_to_parent unless do_not_append_calls
  end


  def parse_path(element)
    @svg_path ||= Path.new

    begin
      commands = @svg_path.parse(element.attributes['d'])
    rescue Prawn::Svg::Parser::Path::InvalidError => e
      commands = []
      @document.warnings << e.message
    end

    element.add_call 'join_style', :bevel

    commands.collect do |command, args|
      if args && args.length > 0
        point_to = [x(args[0]), y(args[1])]
        if command == 'curve_to'
          opts = {:bounds => [[x(args[2]), y(args[3])], [x(args[4]), y(args[5])]]}
        end
        element.add_call command, point_to, opts
      else
        element.add_call command
      end
    end
  end

  def parse_use(element)
    if href = element.attributes['xlink:href']
      if href[0..0] == '#'
        id = href[1..-1]
        if definition_element = @document.elements_by_id[id]
          x = element.attributes['x']
          y = element.attributes['y']
          if x || y
            element.add_call_and_enter "translate", distance(x || 0, :x), -distance(y || 0, :y)
          end
          element.add_calls_from_element definition_element
        else
          @document.warnings << "no tag with ID '#{id}' was found, referenced by use tag"
        end
      else
        @document.warnings << "use tag has an href that is not a reference to an id; this is not supported"
      end
    else
      @document.warnings << "no xlink:href specified on use tag"
    end
  end

  ####################################################################################################################

  def load_css_styles(element)
    if @document.css_parser
      data = if element.element.cdatas.any?
        element.element.cdatas.collect {|d| d.to_s}.join
      else
        element.element.text
      end

      @document.css_parser.add_block!(data)
    end
  end

  def check_attrs_present(element, attrs)
    missing_attrs = attrs - element.attributes.keys
    if missing_attrs.any?
      @document.warnings << "Must have attributes #{missing_attrs.join(", ")} on tag #{element.name}; skipping tag"
    end
    missing_attrs.empty?
  end

  def zero_argument?(*args)
    args.any? {|arg| arg.nil? || arg <= 0}
  end

  %w(x y distance).each do |method|
    define_method(method) {|*a| @document.send(method, *a)}
  end

  def parse_points(points_string)
    points_string.
      to_s.
      strip.
      gsub(/(\d)-(\d)/, '\1 -\2').
      split(COMMA_WSP_REGEXP).
      each_slice(2).
      to_a
  end
end
