module Prawn::SVG
  class Elements::Text < Elements::DirectRenderBase
    Cursor = Struct.new(:x, :y)

    def parse
      @root_component = Elements::TextComponent.new(document, source, [], state.dup)
      @root_component.process

      reintroduce_trailing_and_leading_whitespace
    end

    def render(prawn, renderer)
      @root_component.lay_out(prawn)

      translate_x =
        case @root_component.computed_properties.text_anchor
        when 'middle'
          -@root_component.calculated_width / 2.0
        when 'end'
          -@root_component.calculated_width
        end

      cursor = Cursor.new(0, document.sizing.output_height)
      @root_component.render_component(prawn, renderer, cursor, translate_x)
    end

    private

    def reintroduce_trailing_and_leading_whitespace
      text_nodes = []
      build_text_node_queue(text_nodes, @root_component)

      remove_whitespace_only_text_nodes_and_start_and_end(text_nodes)
      remove_text_nodes_that_are_completely_empty(text_nodes)
      apportion_leading_and_trailing_spaces(text_nodes)
    end

    def build_text_node_queue(queue, component)
      component.children.each do |element|
        case element
        when Elements::TextNode
          queue << element
        else
          build_text_node_queue(queue, element)
        end
      end
    end

    def remove_whitespace_only_text_nodes_and_start_and_end(text_nodes)
      text_nodes.pop   while text_nodes.last  && text_nodes.last.text.empty?
      text_nodes.shift while text_nodes.first && text_nodes.first.text.empty?
    end

    def remove_text_nodes_that_are_completely_empty(text_nodes)
      text_nodes.reject! do |text_node|
        text_node.text.empty? && !text_node.trailing_space? && !text_node.leading_space?
      end
    end

    def apportion_leading_and_trailing_spaces(text_nodes)
      text_nodes.each_cons(2) do |a, b|
        if a.text.empty?
          # Empty strings can only get a leading space from the previous non-empty text,
          # and never get a trailing space
        elsif a.trailing_space?
          a.text += ' '
        elsif b.leading_space?
          b.text = " #{b.text}"
        end
      end
    end
  end
end
