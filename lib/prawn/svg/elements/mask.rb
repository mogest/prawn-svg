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
        # This needs to handle <use> elements and convert them appropriately
        new_call_context_from_base do
          process_child_elements_for_mask
        end
        
        # Add the mask's drawing commands inside the soft_mask block
        element.add_calls_from_element(self)
        
        # Restore to parent context (outside soft_mask block)
        element.pop_call_position
        
        # Now the masked content will be drawn after this
      end
    end

    private

    def process_child_elements_for_mask
      # Override to handle special mask processing
      source.elements.each do |elem|
        case elem.name
        when 'use'
          # Special handling for use elements in masks
          process_use_element_for_mask(elem)
        else
          # Process normally
          process_child_element(elem)
        end
      end
    end

    def process_use_element_for_mask(use_element)
      # Process a use element the standard way
      # This will handle references to images and other elements properly
      use_elem = Prawn::SVG::Elements::Use.new(document, use_element, calls, state.dup)
      begin
        use_elem.process
      rescue Prawn::SVG::Elements::Base::SkipElementError => e
        @document.warnings << "Skipped use element in mask: #{e.message}"
      end
    end

    def find_element_by_id(id)
      # First check the document's cached elements
      if @document.elements_by_id && @document.elements_by_id[id]
        return @document.elements_by_id[id].source
      end
      
      # Otherwise search the document
      REXML::XPath.match(@document.root, %(//*[@id="#{id.gsub('"', '\"')}"])).first
    end

    def process_child_element(elem)
      child = build_element(elem, calls, state.dup)
      child.process if child
    end

    def build_element(source, calls, state)
      klass = Prawn::SVG::Elements::TAG_CLASS_MAPPING[source.name.to_sym]
      return unless klass
      
      klass.new(document, source, calls, state)
    end
  end
end