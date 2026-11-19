module Prawn::SVG
  class Gradients
    def initialize(document)
      @document = document
      @gradients_by_id = {}
      @resolving = Set.new
      @ancestor_states = {}.compare_by_identity
    end

    def [](id)
      id &&= id.strip
      return unless id && id != ''

      @gradients_by_id[id] || resolve(id)
    end

    # The first definition of an id wins, including one resolved early because it was referenced before it was defined.
    def []=(id, gradient)
      @gradients_by_id[id] ||= gradient
    end

    private

    PAINT_SERVER_CLASSES = [Elements::Gradient, Elements::Pattern].freeze

    class AncestorProperties < Elements::Base
      def process
        extract_attributes_and_properties
      end

      protected

      def add_to_elements_by_id?
        false
      end

      # Issues are reported when the element itself is processed.
      def add_source_issue(*); end
    end

    def resolve(id)
      unless @resolving.add?(id)
        @document.add_issue(:invalid, "gradient or pattern '#{id}' is in a reference loop")
        return
      end

      begin
        raw_element = find_raw_gradient_element_by_id(id)
        # An element that turns out to be invalid isn't stored, so isn't returned.
        create_gradient_element(raw_element) if raw_element
        @gradients_by_id[id]
      ensure
        @resolving.delete(id)
      end
    end

    def find_raw_gradient_element_by_id(id)
      raw_element = @document.find_raw_element_by_id(id)
      raw_element if gradient_element?(raw_element)
    end

    def create_gradient_element(raw_element)
      element_class = Elements::TAG_CLASS_MAPPING[raw_element.name.to_sym]
      element_class.new(@document, raw_element, [], state_inside(raw_element.parent).dup).process
    end

    def state_inside(node)
      return new_state unless node.is_a?(REXML::Element)

      @ancestor_states[node] ||= state_inside(node.parent).dup.tap do |state|
        AncestorProperties.new(@document, node, [], state).process
      end
    end

    def gradient_element?(raw_element)
      return false if raw_element.nil? || raw_element.name.nil?

      PAINT_SERVER_CLASSES.include?(Elements::TAG_CLASS_MAPPING[raw_element.name.to_sym])
    end

    def new_state
      State.new.tap do |state|
        state.viewport_sizing = @document.sizing
      end
    end
  end
end
