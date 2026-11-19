#
# Prawn::SVG::Interface makes a Prawn::SVG::Document instance, uses that object to parse the supplied
# SVG into Prawn-compatible method calls, and then calls the Prawn methods.
#
module Prawn
  module SVG
    class Interface
      VALID_OPTIONS = %i[
        at position vposition width height cache_requests cache_images web_requests enable_web_requests
        file_requests enable_file_requests_with_root fallback_font_name color_mode language
        log_issues log_warnings raise_on_issue max_work
      ].freeze

      attr_reader :data, :prawn, :document, :options

      #
      # Creates a Prawn::SVG object.
      #
      # +data+ is the SVG data to convert.  +prawn+ is your Prawn::Document object.
      #
      # See README.md for the options that can be passed to this method.
      #
      def initialize(data, prawn, options, &block)
        verify_options(options)
        verify_raise_on_issue(options[:raise_on_issue])

        @data = data
        @prawn = prawn
        @options = options

        font_registry = Prawn::SVG::FontRegistry.new(prawn.font_families.dup)

        @document = Document.new(
          data, [prawn.bounds.width, prawn.bounds.height], options,
          font_registry: font_registry, &block
        )

        @renderer = Renderer.new(prawn, document, options)
      end

      #
      # Draws the SVG to the Prawn::Document object.
      #
      def draw
        document.work_budget.reset
        @renderer.draw

        document.warnings.each { |w| warn w } if options[:log_issues] || options[:log_warnings]
        raise_on_issues
      end

      def sizing
        document.sizing
      end

      def resize(width: nil, height: nil)
        document.calculate_sizing(requested_width: width, requested_height: height)
      end

      def position
        @renderer.position
      end

      private

      def verify_options(options)
        unknown = options.keys - VALID_OPTIONS
        raise ArgumentError, "Unknown options: #{unknown.map(&:inspect).join(', ')}" if unknown.any?
      end

      def verify_raise_on_issue(categories)
        return if [true, false].include?(categories)

        unknown = Array(categories) - Issue::CATEGORIES
        raise ArgumentError, "Unknown issue categories for raise_on_issue: #{unknown.join(', ')}" if unknown.any?
      end

      def raise_on_issues
        return unless (categories = options[:raise_on_issue])

        issues = document.issues.select { |issue| categories == true || Array(categories).include?(issue.category) }
        raise IssueError, issues if issues.any?
      end
    end
  end
end
