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
      def draw(calls = nil)
        if sizing.invalid?
          document.add_issue(:invalid, 'Negative sizing data means this SVG cannot be rendered') if sizing.negative?
          return
        end

        calls ||= [].tap { |root_calls| Prawn::SVG::Elements::Root.new(document, document.root, root_calls).process }

        prawn.save_font do
          with_font_families do
            prawn.bounding_box(position, width: sizing.output_width, height: sizing.output_height) do
              prawn.save_graphics_state do
                clip_rectangle 0, 0, sizing.output_width, sizing.output_height
                proc_creator(prawn, calls).call
              end
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

      def render_calls(prawn, calls)
        issue_prawn_command(prawn, calls)
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
          raise ArgumentError, 'options[:vposition] must be one of nil, :top, :center, :bottom or a number'
        end
      end

      def proc_creator(prawn, calls)
        proc { issue_prawn_command(prawn, calls) }
      end

      def issue_prawn_command(prawn, calls)
        calls.each do |call, arguments, kwarguments, children|
          skip = false

          rewrite_call_arguments(prawn, call, arguments, kwarguments, children) do
            issue_prawn_command(prawn, children) if children.any?
            skip = true
          end

          if skip
            # the call has been overridden
          elsif children.empty? && call != 'transparent' # some prawn calls complain if they aren't supplied a block
            if kwarguments.empty?
              prawn.send(call, *arguments)
            else
              prawn.send(call, *arguments, **kwarguments)
            end
          elsif kwarguments.empty?
            prawn.send(call, *arguments, &proc_creator(prawn, children))
          else
            prawn.send(call, *arguments, **kwarguments, &proc_creator(prawn, children))
          end
        end
      end

      def rewrite_call_arguments(prawn, call, arguments, kwarguments, children)
        case call
        when 'svg:render'
          element = arguments.first
          raise ArgumentError, "Expected a Prawn::SVG::Elements::DirectRenderBase, got #{element.class}" unless element.is_a?(Prawn::SVG::Elements::DirectRenderBase)

          begin
            use_registry_font_families
            element.render(prawn, self)
          rescue Prawn::SVG::Elements::Base::SkipElementQuietly
          rescue Prawn::SVG::Elements::Base::SkipElementError => e
            @document.add_issue(e.category, e.message)
          end

          yield

        when 'svg:yield'
          block = arguments.first
          block.call
          yield

        when 'transformation_matrix'
          left = prawn.bounds.absolute_left
          top = prawn.bounds.absolute_top
          arguments[4] += left - ((left * arguments[0]) + (top * arguments[2]))
          arguments[5] += top - ((left * arguments[1]) + (top * arguments[3]))

        when 'curve_to'
          # Prawn appends the destination to bounds, mutating bounds.
          # Preserve it for path replay by passing a .dup instead.
          # See: https://github.com/prawnpdf/prawn/issues/1401
          prawn.curve_to(arguments.first, **kwarguments.merge(bounds: kwarguments[:bounds].dup))
          yield

        when 'miter_limit'
          prawn.add_content("#{arguments.first} M")
          yield

        when 'clip'
          even_odd = kwarguments[:clip_rule] == :even_odd
          prawn.add_content(even_odd ? 'W* n' : 'W n')
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
          # Using separate fill and stroke operations instead of the combined B operator.
          # Chromium's PDF renderer (PDFium) doesn't correctly apply stroke alpha (CA) with
          # the B operator when fill and stroke have different opacities.
          # Also avoids Prawn's 'b' which includes closepath (h) that breaks dashes and line caps.
          even_odd = kwarguments[:fill_rule] == :even_odd
          prawn.add_content(even_odd ? 'f*' : 'f')
          issue_prawn_command(prawn, children)
          prawn.add_content('S')

        when 'noop'
          yield

        when 'svg:image'
          begin
            prawn.image(*arguments, **kwarguments)
          rescue StandardError
            # Prawn's image parsers raise arbitrary errors on corrupt data, which may have come from anywhere.  Some
            # are only found when the image is drawn, so they aren't checked when the <image> is parsed.
            document.add_issue(:resource, Prawn::SVG::Elements::Image::UNPARSEABLE_IMAGE_MESSAGE)
          end
          yield

        when 'svg:render_sub_document'
          sub_document, sub_calls = arguments
          Renderer.new(prawn, sub_document, at: [0, 0]).draw(sub_calls)
          yield

        when 'soft_mask'
          with_large_page_dimensions(prawn) do
            prawn.soft_mask do
              issue_prawn_command(prawn, children) if children.any?
            end
          end
          # Clear children so issue_prawn_command doesn't re-process them
          # after soft_mask has already rendered them above.
          children.clear
          yield

        when 'svg:render_gradient'
          type = arguments.first
          GradientRenderer.new(prawn, type, **kwarguments).draw
          yield

        when 'svg:render_pattern'
          type = arguments[0]
          PatternRenderer.new(prawn, type, self, **kwarguments).draw
          yield

        when 'svg:add_link'
          LinkRenderer.new(*arguments).render(prawn)
          yield
        end
      end

      def with_font_families
        yield
      ensure
        prawn.font_families.replace(@saved_font_families) if @saved_font_families
        @saved_font_families = nil
      end

      # Only text needs the registry's fonts, and loading them scans the installed fonts, so wait until there is some.
      def use_registry_font_families
        return if @saved_font_families || document.font_registry.nil?

        @saved_font_families = prawn.font_families.dup
        prawn.font_families.replace(document.font_registry.installed_fonts)
      end

      # Prawn's soft_mask hardcodes BBox to page.dimensions, which causes
      # Chrome and Firefox to clip mask content that extends beyond the page.
      # Temporarily override dimensions to use a large BBox.
      def with_large_page_dimensions(prawn)
        page = prawn.state.page
        return yield if page.singleton_methods.include?(:dimensions)

        large_bbox = [-10_000, -10_000, 10_000, 10_000]
        page.define_singleton_method(:dimensions) { large_bbox }
        begin
          yield
        ensure
          page.singleton_class.remove_method(:dimensions)
        end
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
