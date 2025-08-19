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
      # Apply the mask to the element  
      element.new_call_context_from_base do
        # Save graphics state first
        element.add_call 'save_graphics_state'
        
        # Store current position before entering soft_mask
        element.push_call_position
        
        # Create soft mask with the mask's content as nested calls
        element.add_call_and_enter 'soft_mask'
        
        # Process mask's child elements to get drawing commands for the mask
        # First process my children to generate the mask pattern
        new_call_context_from_base do
          process_child_elements
        end
        
        # Add the mask's drawing commands inside the soft_mask block
        element.add_calls_from_element(self)
        
        # Restore to parent context (outside soft_mask block)
        element.pop_call_position
        
        # Now the masked content will be drawn after this
      end
    end
  end
end
