module Prawn::SVG::Elements
  class Mask < Base
    include Prawn::SVG::Calculators::UnitInterval

    attr_reader :mask_units, :mask_content_units

    def parse
      @mask_units = attributes['maskUnits'] || 'objectBoundingBox'
      @mask_content_units = attributes['maskContentUnits'] || 'userSpaceOnUse'

      if @mask_content_units == 'objectBoundingBox'
        @document.warnings << "maskContentUnits='objectBoundingBox' on mask element is not supported"
      end

      if mask_units == 'userSpaceOnUse'
        @x = x(attributes['x'] || '-10%')
        @y = y(attributes['y'] || '-10%')
        @width = x_pixels(attributes['width'] || '120%')
        @height = y_pixels(attributes['height'] || '120%')
      else
        @x = to_unit_interval(attributes['x'] || '-0.1')
        @y = to_unit_interval(attributes['y'] || '-0.1')
        @width = to_unit_interval(attributes['width'] || '1.2')
        @height = to_unit_interval(attributes['height'] || '1.2')
      end
    end

    def container?
      true
    end

    def isolate_children?
      false
    end

    def apply_mask(element)
      element.new_call_context_from_base do
        if mask_units == 'userSpaceOnUse'
          location = [@x, @y]
          size = [@width, @height]
        else
          bounding_x1, bounding_y1, bounding_x2, bounding_y2 = element.bounding_box
          return if bounding_y2.nil?

          bounding_width = bounding_x2 - bounding_x1
          bounding_height = bounding_y2 - bounding_y1

          location = [
            bounding_x1 + bounding_width * @x,
            bounding_y1 - bounding_height * @y
          ]

          size = [bounding_width * @width, bounding_height * @height]
        end

        element.add_call 'rectangle', location, size[0], size[1]
        element.add_call 'clip'

        element.add_call_and_enter('soft_mask')
        element.add_calls_from_element(self)
      end
    end
  end
end
