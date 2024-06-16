#
# Prawn::SVG::Interface makes a Prawn::SVG::Document instance, uses that object to parse the supplied
# SVG into Prawn-compatible method calls, and then calls the Prawn methods.
#
module Prawn
  module SVG
    class Interface
      VALID_OPTIONS = %i[
        at position vposition width height cache_images enable_web_requests
        enable_file_requests_with_root fallback_font_name color_mode
      ].freeze

      INHERITABLE_OPTIONS = %i[
        enable_web_requests enable_file_requests_with_root
        cache_images fallback_font_name color_mode
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
        Prawn.verify_options VALID_OPTIONS, options

        @data = data
        @prawn = prawn
        @options = options

        font_registry = Prawn::SVG::FontRegistry.new(prawn.font_families)

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
        @renderer.draw
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

      # backwards support for when the font_path used to be stored on this class
      def self.font_path
        Prawn::SVG::FontRegistry.font_path
      end
    end
  end
end
