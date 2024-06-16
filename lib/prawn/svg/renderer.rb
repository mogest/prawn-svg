module Prawn
  module SVG
    class Renderer
      attr_reader :prawn, :document, :options

      #
      # Creates a Prawn::SVG object.
      #
      # +data+ is the SVG data to convert.  +prawn+ is your Prawn::Document object.
      #
      # See README.md for the options that can be passed to this method.
      #
      def initialize(prawn, document, options)
        @prawn = prawn
        @document = document
        @options = options
      end

      #
      # Draws the SVG to the Prawn::Document object.
      #
      def draw
        if sizing.invalid?
          document.warnings << 'Zero or negative sizing data means this SVG cannot be rendered'
          return
        end

        document.warnings.clear

        prawn.save_font do
          prawn.bounding_box(position, width: sizing.output_width, height: sizing.output_height) do
            prawn.save_graphics_state do
              clip_rectangle 0, 0, sizing.output_width, sizing.output_height

              calls = []
              root_element = Prawn::SVG::Elements::Root.new(document, document.root, calls)
              root_element.process

              proc_creator(prawn, calls).call
            end
          end
        end
      end

      def sizing
        document.sizing
      end

      def position
        options[:at] || [x_based_on_requested_alignment, y_based_on_requested_alignment]
      end

      private

      def x_based_on_requested_alignment
        case options[:position]
        when :left, nil
          0
        when :center, :centre
          (sizing.bounds[0] - sizing.output_width) / 2.0
        when :right
          sizing.bounds[0] - sizing.output_width
        when Numeric
          options[:position]
        else
          raise ArgumentError, 'options[:position] must be one of nil, :left, :right, :center or a number'
        end
      end

      def y_based_on_requested_alignment
        case options[:vposition]
        when nil
          prawn.cursor
        when :top
          sizing.bounds[1]
        when :center, :centre
          sizing.bounds[1] - ((sizing.bounds[1] - sizing.output_height) / 2.0)
        when :bottom
          sizing.output_height
        when Numeric
          sizing.bounds[1] - options[:vposition]
        else
          raise ArgumentError, 'options[:vposition] must be one of nil, :top, :right, :bottom or a number'
        end
      end

      def proc_creator(prawn, calls)
        proc { issue_prawn_command(prawn, calls) }
      end

      def issue_prawn_command(prawn, calls)
        calls.each do |call, arguments, kwarguments, children|
          skip = false

          rewrite_call_arguments(prawn, call, arguments, kwarguments) do
            issue_prawn_command(prawn, children) if children.any?
            skip = true
          end

          if skip
            # the call has been overridden
          elsif children.empty? && call != 'transparent' # some prawn calls complain if they aren't supplied a block
            if RUBY_VERSION >= '2.7' || !kwarguments.empty?
              prawn.send(call, *arguments, **kwarguments)
            else
              prawn.send(call, *arguments)
            end
          elsif RUBY_VERSION >= '2.7' || !kwarguments.empty?
            prawn.send(call, *arguments, **kwarguments, &proc_creator(prawn, children))
          else
            prawn.send(call, *arguments, &proc_creator(prawn, children))
          end
        end
      end

      def rewrite_call_arguments(prawn, call, arguments, kwarguments)
        case call
        when 'text_group'
          @cursor = [0, sizing.output_height]
          yield

        when 'draw_text'
          text = arguments.first
          options = kwarguments

          at = options.fetch(:at)

          at[0] = @cursor[0] if at[0] == :relative
          at[1] = @cursor[1] if at[1] == :relative

          case options.delete(:dominant_baseline)
          when 'middle'
            height = prawn.font.height
            at[1] -= height / 2.0
            @cursor = [at[0], at[1]]
          end

          if (offset = options.delete(:offset))
            at[0] += offset[0]
            at[1] -= offset[1]
          end

          width = prawn.width_of(text, options.merge(kerning: true))

          if (stretch_to_width = options.delete(:stretch_to_width))
            factor = stretch_to_width.to_f * 100 / width.to_f
            prawn.add_content "#{factor} Tz"
            width = stretch_to_width.to_f
          end

          if (pad_to_width = options.delete(:pad_to_width))
            padding_required = pad_to_width.to_f - width.to_f
            padding_per_character = padding_required / text.length.to_f
            prawn.add_content "#{padding_per_character} Tc"
            width = pad_to_width.to_f
          end

          case options.delete(:text_anchor)
          when 'middle'
            at[0] -= width / 2
            @cursor = [at[0] + (width / 2), at[1]]
          when 'end'
            at[0] -= width
            @cursor = at.dup
          else
            @cursor = [at[0] + width, at[1]]
          end

          decoration = options.delete(:decoration)
          if decoration == 'underline'
            prawn.save_graphics_state do
              prawn.line_width 1
              prawn.line [at[0], at[1] - 1.25], [at[0] + width, at[1] - 1.25]
              prawn.stroke
            end
          end

        when 'transformation_matrix'
          left = prawn.bounds.absolute_left
          top = prawn.bounds.absolute_top
          arguments[4] += left - ((left * arguments[0]) + (top * arguments[2]))
          arguments[5] += top - ((left * arguments[1]) + (top * arguments[3]))

        when 'clip'
          prawn.add_content 'W n' # clip to path
          yield

        when 'save'
          prawn.save_graphics_state
          yield

        when 'restore'
          prawn.restore_graphics_state
          yield

        when 'end_path'
          yield
          prawn.add_content 'n' # end path

        when 'fill_and_stroke'
          yield
          # prawn (as at 2.0.1 anyway) uses 'b' for its fill_and_stroke.  'b' is 'h' (closepath) + 'B', and we
          # never want closepath to be automatically run as it stuffs up many drawing operations, such as dashes
          # and line caps, and makes paths close that we didn't ask to be closed when fill is specified.
          even_odd = kwarguments[:fill_rule] == :even_odd
          content  = even_odd ? 'B*' : 'B'
          prawn.add_content content

        when 'noop'
          yield

        when 'svg:render_sub_document'
          sub_document = arguments.first
          sub_options = inheritable_options.merge({ at: [0, 0] })

          Renderer.new(prawn, sub_document, sub_options).draw
          document.warnings.concat(sub_document.warnings)
          yield
        end
      end

      def inheritable_options
        (options || {}).slice(Prawn::SVG::Interface::INHERITABLE_OPTIONS)
      end

      def clip_rectangle(x, y, width, height)
        prawn.move_to x, y
        prawn.line_to x + width, y
        prawn.line_to x + width, y + height
        prawn.line_to x, y + height
        prawn.close_path
        prawn.add_content 'W n' # clip to path
      end
    end
  end
end
