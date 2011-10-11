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
  CONTAINER_TAGS = %w(g svg symbol defs)
  
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
    root_element = Prawn::Svg::Element.new(@document, @document.root, calls, :ids => {}, :fill => true)
    
    parse_element(root_element)
    calls
  end


  private  
  REQUIRED_ATTRIBUTES = {
    "line"      => %w(x1 y1 x2 y2),
    "polyline"  => %w(points),
    "polygon"   => %w(points),
    "circle"    => %w(r),
    "ellipse"   => %w(rx ry),
    "rect"      => %w(width height),
    "path"      => %w(d)    
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
      element.each_child_element do |child|
        element.add_call "save"
        parse_element(child)
        element.add_call "restore"
      end
      
      do_not_append_calls = %w(symbol defs).include?(element.name)
          
    when 'style'
      load_css_styles(element)

    when 'text'
      @svg_text ||= Text.new
      @svg_text.parse(element)

    when 'line'
      element.add_call 'line', x(attrs['x1']), y(attrs['y1']), x(attrs['x2']), y(attrs['y2'])

    when 'polyline'
      points = attrs['points'].split(/\s+/)
      return unless base_point = points.shift
      x, y = base_point.split(",")
      element.add_call 'move_to', x(x), y(y)
      element.add_call_and_enter 'stroke'
      points.each do |point|
        x, y = point.split(",")
        element.add_call "line_to", x(x), y(y)
      end

    when 'polygon'
      points = attrs['points'].split(/\s+/).collect do |point|
        x, y = point.split(",")
        [x(x), y(y)]
      end
      element.add_call "polygon", *points
  
    when 'circle'
      if USE_NEW_CIRCLE_CALL
        element.add_call "circle", 
          [x(attrs['cx'] || "0"), y(attrs['cy'] || "0")], distance(attrs['r'])
      else
        element.add_call "circle_at", 
          [x(attrs['cx'] || "0"), y(attrs['cy'] || "0")], :radius => distance(attrs['r'])
      end
      
    when 'ellipse'
      element.add_call USE_NEW_ELLIPSE_CALL ? "ellipse" : "ellipse_at", 
        [x(attrs['cx'] || "0"), y(attrs['cy'] || "0")], distance(attrs['rx']), distance(attrs['ry'])
  
    when 'rect'
      radius = distance(attrs['rx'] || attrs['ry'])
      args = [[x(attrs['x'] || '0'), y(attrs['y'] || '0')], distance(attrs['width']), distance(attrs['height'])]
      if radius
        # n.b. does not support both rx and ry being specified with different values
        element.add_call "rounded_rectangle", *(args + [radius])
      else
        element.add_call "rectangle", *args
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

    commands.collect do |command, args|
      point_to = [x(args[0]), y(args[1])]
      if command == 'curve_to'
        opts = {:bounds => [[x(args[2]), y(args[3])], [x(args[4]), y(args[5])]]}
      end
      element.add_call command, point_to, opts
    end  
  end
  
  def parse_use(element)
    if href = element.attributes['xlink:href']
      if href[0..0] == '#'
        id = href[1..-1]
        if id_calls = element.state[:ids][id]
          x = element.attributes['x']
          y = element.attributes['y']
          if x || y
            element.add_call_and_enter "translate", distance(x || 0), -distance(y || 0)
          end
          
          element.calls.concat(id_calls)              
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
  
  %w(x y distance).each do |method|
    define_method(method) {|*a| @document.send(method, *a)}
  end
end
