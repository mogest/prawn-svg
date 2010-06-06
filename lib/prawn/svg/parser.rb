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
module Prawn
  module Svg
    class Parser
      DEFAULT_WIDTH  = 640
      DEFAULT_HEIGHT = 480
      
      CONTAINER_TAGS = %w(g svg symbol defs)
      
      begin
        require 'css_parser'
        CSS_PARSER_LOADED = true
      rescue LoadError
        CSS_PARSER_LOADED = false
      end
  
      include Prawn::Measurements
  
      attr_reader :width, :height
  
      # An +Array+ of warnings that occurred while parsing the SVG data.
      attr_reader :warnings

      # The scaling factor, as determined by the :width or :height options.
      attr_accessor :scale
  
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
      def initialize(data, bounds, options)
        @data = data
        @bounds = bounds
        @options = options
        @warnings = []
        @css_parser = CssParser::Parser.new if CSS_PARSER_LOADED
    
        if data
          parse_document
          calculate_dimensions
        end
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
        @warnings = []
        calls = [['fill_color', '000000', []]]
        parse_element(@root, calls, {:ids => {}, :fill => true})
        calls
      end


      private  
      def parse_document
        @root = REXML::Document.new(@data).root
        @actual_width, @actual_height = @bounds # set this first so % width/heights can be used

        if vb = @root.attributes['viewBox']
          x1, y1, x2, y2 = vb.strip.split(/\s+/)
          @x_offset, @y_offset = [x1.to_f, y1.to_f]
          @actual_width, @actual_height = [x2.to_f - x1.to_f, y2.to_f - y1.to_f]
        else
          @x_offset, @y_offset = [0, 0]
          @actual_width = points(@root.attributes['width'] || DEFAULT_WIDTH, :x)
          @actual_height = points(@root.attributes['height'] || DEFAULT_HEIGHT, :y)
        end
      end
    
      REQUIRED_ATTRIBUTES = {
        "line"      => %w(x1 y1 x2 y2),
        "polyline"  => %w(points),
        "polygon"   => %w(points),
        "circle"    => %w(r),
        "ellipse"   => %w(rx ry),
        "rect"      => %w(x y width height),
        "path"      => %w(d)    
      }
    
      def parse_element(element, parent_calls, state)
        attrs = element.attributes

        element_calls = []
        calls, style_attrs = apply_styles(element, element_calls, state)

        if required_attributes = REQUIRED_ATTRIBUTES[element.name]
          return unless check_attrs_present(element, required_attributes)
        end
            
        case element.name
        when 'title', 'desc'
          # ignore
          do_not_append_calls = true
      
        when *CONTAINER_TAGS
          element.elements.each do |child|
            parse_element(child, calls, state.dup)
          end
          
          do_not_append_calls = %w(symbol defs).include?(element.name)
              
        when 'style'
          load_css_styles(element)

        when 'text'
          if font_family = style_attrs["font-family"]
            if font_family != "" && pdf_font = map_font_family_to_pdf_font(font_family)
              calls << ['font', [pdf_font], []]
              calls = calls.last.last
            else
              @warnings << "#{font_family} is not a known font."
            end
          end
      
          opts = {:at => [x(attrs['x']), y(attrs['y'])]}
          if size = style_attrs['font-size']
            opts[:size] = size.to_f * @scale
          end
            
          # This is not a prawn option but we can't work out how to render it here -
          # it's handled by Svg#rewrite_call_arguments
          if anchor = style_attrs['text-anchor']
            opts[:text_anchor] = anchor        
          end
      
          text = element.text.strip.gsub(/\s+/, " ")
          calls << ['draw_text', [text, opts], []]

        when 'line'
          calls << ['line', [x(attrs['x1']), y(attrs['y1']), x(attrs['x2']), y(attrs['y2'])], []]

        when 'polyline'
          points = attrs['points'].split(/\s+/)
          return unless base_point = points.shift
          x, y = base_point.split(",")
          calls << ['move_to', [x(x), y(y)], []]
          calls << ['stroke', [], []]
          calls = calls.last.last
          points.each do |point|
            x, y = point.split(",")
            calls << ["line_to", [x(x), y(y)], []]
          end
    
        when 'polygon'
          points = attrs['points'].split(/\s+/).collect do |point|
            x, y = point.split(",")
            [x(x), y(y)]
          end
          calls << ["polygon", points, []]      
      
        when 'circle'
          calls << ["circle_at", 
            [[x(attrs['cx'] || "0"), y(attrs['cy'] || "0")], {:radius => distance(attrs['r'])}], 
            []]
      
        when 'ellipse'
          calls << ["ellipse_at", 
            [[x(attrs['cx'] || "0"), y(attrs['cy'] || "0")], distance(attrs['rx']), distance(attrs['ry'])],
            []]
      
        when 'rect'
          radius = distance(attrs['rx'] || attrs['ry'])
          args = [[x(attrs['x']), y(attrs['y'])], distance(attrs['width']), distance(attrs['height'])]
          if radius
            # n.b. does not support both rx and ry being specified with different values
            calls << ["rounded_rectangle", args + [radius], []]
          else
            calls << ["rectangle", args, []]
          end
      
        when 'path'
          @svg_path ||= Path.new

          begin
            commands = @svg_path.parse(attrs['d'])
          rescue Prawn::Svg::Parser::Path::InvalidError => e
            commands = []
            @warnings << e.message
          end

          run_path_commands(commands, calls)
          
        when 'use'
          if href = attrs['href']
            if href[0..0] == '#'
              id = href[1..-1]
              if id_calls = state[:ids][id]
                if attrs['x'] || attrs['y']
                  calls << ["translate", [distance(attrs['x']), -distance(attrs['y'])], []]
                  calls = calls.last.last
                end
                
                calls.concat(id_calls)              
              else
                @warnings << "no tag with ID '#{id}' was found, referenced by use tag"
              end
            else
              @warnings << "use tag has an href that is not a reference to an id; this is not supported"
            end
          else
            @warnings << "no xlink:href specified on use tag"
          end              

        else 
          @warnings << "Unknown tag '#{element.name}'; ignoring"
        end
        
        state[:ids][attrs['id']] = element_calls if attrs['id']
        parent_calls.concat(element_calls) unless do_not_append_calls
      end
  
      def load_css_styles(element)
        if @css_parser
          data = if element.cdatas.any?
            element.cdatas.collect {|d| d.to_s}.join
          else
            element.text
          end
    
          @css_parser.add_block!(data) 
        end    
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
  
      def determine_style_for(element)
        if @css_parser
          tag_style = @css_parser.find_by_selector(element.name)
          id_style = @css_parser.find_by_selector("##{element.attributes["id"]}") if element.attributes["id"]
      
          if classes = element.attributes["class"]
            class_styles = classes.strip.split(/\s+/).collect do |class_name|
              @css_parser.find_by_selector(".#{class_name}")
            end
          end
      
          element_style = element.attributes['style']

          style = [tag_style, class_styles, id_style, element_style].flatten.collect do |s|
            s.nil? || s.strip == "" ? "" : "#{s}#{";" unless s.match(/;\s*\z/)}"
          end.join
        else
          style = element.attributes['style'] || ""
        end

        decs = parse_css_declarations(style)
        element.attributes.each {|n,v| decs[n] = v unless decs[n]}
        decs
      end
  
      def apply_styles(element, calls, state)
        decs = determine_style_for(element)    
    
        # Transform
        if transform = decs['transform']
          parse_css_method_calls(transform).each do |name, arguments|
            case name
            when 'translate'
              x, y = arguments
              x, y = x.split(/\s+/) if y.nil?
              calls << [name, [distance(x), -distance(y)], []]
              calls = calls.last.last
            when 'rotate'          
              calls << [name, [-arguments.first.to_f, {:origin => [0, y('0')]}], []]
              calls = calls.last.last
            when 'scale'
              args = arguments.first.split(/\s+/)
              x_scale = args[0].to_f
              y_scale = (args[1] || x_scale).to_f
              calls << ["transformation_matrix", [x_scale, 0, 0, y_scale, 0, 0], []]
              calls = calls.last.last
            when 'matrix'
              args = arguments.first.split(/\s+/)
              if args.length != 6
                @warnings << "transform 'matrix' must have six arguments"
              else
                a, b, c, d, e, f = args.collect {|a| a.to_f}
                calls << ["transformation_matrix", [a, b, c, d, distance(e), -distance(f)], []]
                calls = calls.last.last
              end
            else
              @warnings << "Unknown transformation '#{name}'; ignoring"
            end
          end
        end    
            
        # Opacity:
        # We can't do nested opacities quite like the SVG requires, but this is close enough.
        fill_opacity = stroke_opacity = clamp(decs['opacity'].to_f, 0, 1) if decs['opacity']
        fill_opacity = clamp(decs['fill-opacity'].to_f, 0, 1) if decs['fill-opacity']
        stroke_opacity = clamp(decs['stroke-opacity'].to_f, 0, 1) if decs['stroke-opacity']
    
        if fill_opacity || stroke_opacity      
          state[:fill_opacity] = (state[:fill_opacity] || 1) * (fill_opacity || 1)
          state[:stroke_opacity] = (state[:stroke_opacity] || 1) * (stroke_opacity || 1)

          calls << ['transparent', [state[:fill_opacity], state[:stroke_opacity]], []] 
          calls = calls.last.last
        end

        # Fill and stroke
        draw_types = []  
        [:fill, :stroke].each do |type|
          dec = decs[type.to_s]
          if dec == "none"
            state[type] = false
          elsif dec
            state[type] = true
            if color = color_to_hex(dec)
              calls << ["#{type}_color", [color], []]
            end
          end

          draw_types << type.to_s if state[type]
        end
    
        calls << ['line_width', [distance(decs['stroke-width'])], []] if decs['stroke-width']  
    
        draw_type = draw_types.join("_and_")
        if draw_type != "" && !CONTAINER_TAGS.include?(element.name)
          calls << [draw_type, [], []]
          calls = calls.last.last
        end            
        
        [calls, decs]
      end
  
      def parse_css_method_calls(string)
        string.scan(/\s*(\w+)\(([^)]+)\)\s*/).collect do |call|
          name, argument_string = call
          arguments = argument_string.split(",").collect {|s| s.strip}
          [name, arguments]
        end    
      end
  
      BUILT_IN_FONTS = ["Courier", "Helvetica", "Times-Roman", "Symbol", "ZapfDingbats"]
      GENERIC_CSS_FONT_MAPPING = {
        "serif"      => "Times-Roman",
        "sans-serif" => "Helvetica",
        "cursive"    => "Times-Roman",
        "fantasy"    => "Times-Roman",
        "monospace"  => "Courier"}
    
      def installed_fonts
        @installed_fonts ||= Prawn::Svg::Interface.font_path.uniq.collect {|path| Dir["#{path}/*"]}.flatten
      end
  
      def map_font_family_to_pdf_font(font_family)
        font_family.split(",").detect do |font|
          font = font.gsub(/['"]/, '').gsub(/\s{2,}/, ' ').strip.downcase
      
          built_in_font = BUILT_IN_FONTS.detect {|f| f.downcase == font}
          break built_in_font if built_in_font
      
          generic_font = GENERIC_CSS_FONT_MAPPING[font]
          break generic_font if generic_font
      
          installed_font = installed_fonts.detect do |file|
            (matches = File.basename(file).match(/(.+)\./)) && matches[1].downcase == font
          end
          break installed_font if installed_font
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
  
      def x(value)
        (points(value, :x) - @x_offset) * scale
      end
  
      def y(value)
        (@actual_height - (points(value, :y) - @y_offset)) * scale
      end
  
      def distance(value, axis = nil)
        value && (points(value, axis) * scale)
      end
  
      def points(value, axis = nil)
        if value.is_a?(String)
          if match = value.match(/\d(cm|dm|ft|in|m|mm|yd)$/)
            send("#{match[1]}2pt", value.to_f)
          elsif value[-1..-1] == "%"
            value.to_f * (axis == :y ? @actual_height : @actual_width) / 100.0
          else
            value.to_f
          end
        else
          value.to_f
        end
      end
  
      def calculate_dimensions    
        if @options[:width]
          @width = @options[:width]      
          @scale = @options[:width] / @actual_width.to_f
        elsif @options[:height]
          @height = @options[:height]
          @scale = @options[:height] / @actual_height.to_f
        else
          @scale = 1
        end
    
        @width ||= @actual_width * @scale
        @height ||= @actual_height * @scale
      end
  
      def clamp(value, min_value, max_value)
        [[value, min_value].max, max_value].min
      end  
  
      def check_attrs_present(element, attrs)
        missing_attrs = attrs - element.attributes.keys
        if missing_attrs.any?
          @warnings << "Must have attributes #{missing_attrs.join(", ")} on tag #{element.name}; skipping tag"
        end
        missing_attrs.empty?
      end
      
      def run_path_commands(commands, calls)
        commands.collect do |command, args|
          point_to = [x(args[0]), y(args[1])]
          if command == 'curve_to'
            bounds = [[x(args[2]), y(args[3])], [x(args[4]), y(args[5])]]
            calls << [command, [point_to, {:bounds => bounds}], []]
          else
            calls << [command, point_to, []]
          end
        end
      end      
    end
  end
end
