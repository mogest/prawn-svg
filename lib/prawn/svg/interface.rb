#
# Prawn::SVG::Interface makes a Prawn::SVG::Document instance, uses that object to parse the supplied
# SVG into Prawn-compatible method calls, and then calls the Prawn methods.
#
module Prawn
  module SVG
    class Interface
      VALID_OPTIONS = [:at, :position, :vposition, :width, :height, :cache_images, :fallback_font_name]

      DEFAULT_FONT_PATHS = ["/Library/Fonts", "/System/Library/Fonts", "#{ENV["HOME"]}/Library/Fonts", "/usr/share/fonts/truetype"]

      @font_path = []
      DEFAULT_FONT_PATHS.each {|path| @font_path << path if File.exists?(path)}

      class << self; attr_accessor :font_path; end

      attr_reader :data, :prawn, :document, :options

      #
      # Creates a Prawn::SVG object.
      #
      # +data+ is the SVG data to convert.  +prawn+ is your Prawn::Document object.
      #
      # Options:
      # <tt>:at</tt>:: an array [x,y] specifying the location of the top-left corner of the SVG.
      # <tt>:position</tt>::  one of (nil, :left, :center, :right) or an x-offset
      # <tt>:vposition</tt>::  one of (nil, :top, :center, :bottom) or a y-offset
      # <tt>:width</tt>:: the width that the SVG is to be rendered
      # <tt>:height</tt>:: the height that the SVG is to be rendered
      #
      # If <tt>:at</tt> is provided, the SVG will be placed in the current page but
      # the text position will not be changed.
      #
      # If both <tt>:width</tt> and <tt>:height</tt> are specified, only the width will be used.
      #
      def initialize(data, prawn, options, &block)
        Prawn.verify_options VALID_OPTIONS, options

        @data = data
        @prawn = prawn
        @options = options

        Prawn::SVG::Font.load_external_fonts(prawn.font_families)

        @document = Document.new(data, [prawn.bounds.width, prawn.bounds.height], options, &block)
      end

      #
      # Draws the SVG to the Prawn::Document object.
      #
      def draw
        if @document.sizing.invalid?
          @document.warnings << "Zero or negative sizing data means this SVG cannot be rendered"
          return
        end

        @document.warnings.clear

        prawn.bounding_box(position, :width => @document.sizing.output_width, :height => @document.sizing.output_height) do
          prawn.save_graphics_state do
            clip_rectangle 0, 0, @document.sizing.output_width, @document.sizing.output_height

            calls = []
            root_element = Prawn::SVG::Elements::Root.new(@document, @document.root, calls, fill: true)
            root_element.process

            proc_creator(prawn, calls).call
          end
        end
      end

      def position
        @options[:at] || [x_based_on_requested_alignment, y_based_on_requested_alignment]
      end

      private

      def x_based_on_requested_alignment
        case options[:position]
        when :left, nil
          0
        when :center, :centre
          (@document.sizing.bounds[0] - @document.sizing.output_width) / 2.0
        when :right
          @document.sizing.bounds[0] - @document.sizing.output_width
        when Numeric
          options[:position]
        else
          raise ArgumentError, "options[:position] must be one of nil, :left, :right, :center or a number"
        end
      end

      def y_based_on_requested_alignment
        case options[:vposition]
        when nil
          prawn.cursor
        when :top
          @document.sizing.bounds[1]
        when :center, :centre
          @document.sizing.bounds[1] - (@document.sizing.bounds[1] - @document.sizing.output_height) / 2.0
        when :bottom
          @document.sizing.output_height
        when Numeric
          @document.sizing.bounds[1] - options[:vposition]
        else
          raise ArgumentError, "options[:vposition] must be one of nil, :top, :right, :bottom or a number"
        end
      end

      def proc_creator(prawn, calls)
        Proc.new {issue_prawn_command(prawn, calls)}
      end

      def issue_prawn_command(prawn, calls)
        calls.each do |call, arguments, children|
          skip = false

          rewrite_call_arguments(prawn, call, arguments) do
            issue_prawn_command(prawn, children) if children.any?
            skip = true
          end

          if skip
            # the call has been overridden
          elsif children.empty?
            prawn.send(call, *arguments)
          else
            prawn.send(call, *arguments, &proc_creator(prawn, children))
          end
        end
      end

      def rewrite_call_arguments(prawn, call, arguments)
        if call == 'relative_draw_text'
          call.replace "draw_text"
          arguments.last[:at][0] = @relative_text_position if @relative_text_position
        end

        case call
        when 'text_group'
          @relative_text_position = nil
          yield

        when 'draw_text'
          text, options = arguments

          width = prawn.width_of(text, options.merge(:kerning => true))

          if (anchor = options.delete(:text_anchor)) && %w(middle end).include?(anchor)
            width /= 2 if anchor == 'middle'
            options[:at][0] -= width
          end

          space_width = prawn.width_of("n", options)
          @relative_text_position = options[:at][0] + width + space_width

        when 'transformation_matrix'
          left = prawn.bounds.absolute_left
          top = prawn.bounds.absolute_top
          arguments[4] += left - (left * arguments[0] + top * arguments[2])
          arguments[5] += top - (left * arguments[1] + top * arguments[3])

        when 'clip'
          prawn.add_content "W n" # clip to path
          yield

        when 'save'
          prawn.save_graphics_state
          yield

        when 'restore'
          prawn.restore_graphics_state
          yield

        when "end_path"
          yield
          prawn.add_content "n" # end path

        when 'fill_and_stroke'
          yield
          # prawn (as at 2.0.1 anyway) uses 'b' for its fill_and_stroke.  'b' is 'h' (closepath) + 'B', and we
          # never want closepath to be automatically run as it stuffs up many drawing operations, such as dashes
          # and line caps, and makes paths close that we didn't ask to be closed when fill is specified.
          prawn.add_content 'B'
        end
      end

      def clip_rectangle(x, y, width, height)
          prawn.move_to x, y
          prawn.line_to x + width, y
          prawn.line_to x + width, y + height
          prawn.line_to x, y + height
          prawn.close_path
          prawn.add_content "W n" # clip to path
      end
    end
  end
end
