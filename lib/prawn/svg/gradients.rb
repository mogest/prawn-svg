module Prawn::SVG
  class Gradients
    def initialize(document)
      @document = document
      @gradients_by_id = {}
    end

    def [](id)
      id &&= id.strip
      return unless id && id != ''

      if (element = @gradients_by_id[id])
        element
      elsif (raw_element = find_raw_gradient_element_by_id(id))
        create_gradient_element(raw_element)
      end
    end

    def []=(id, gradient)
      @gradients_by_id[id] = gradient
    end

    private

    def find_raw_gradient_element_by_id(id)
      raw_element = find_raw_element_by_id(id)
      raw_element if gradient_element?(raw_element)
    end

    def create_gradient_element(raw_element)
      Elements::Gradient.new(@document, raw_element, [], new_state).tap(&:process)
    end

    def find_raw_element_by_id(id)
      REXML::XPath.match(@document.root, %(//*[@id="#{id.gsub('"', '\"')}"])).first
    end

    def gradient_element?(raw_element)
      return false if raw_element.nil? || raw_element.name.nil?

      Elements::TAG_CLASS_MAPPING[raw_element.name.to_sym] == Elements::Gradient
    end

    def new_state
      State.new.tap do |state|
        state.viewport_sizing = @document.sizing
      end
    end
  end
end
