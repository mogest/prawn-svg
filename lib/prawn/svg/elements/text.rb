module Prawn::SVG
  class Elements::Text < Elements::DirectRenderBase
    Cursor = Struct.new(:x, :y)

    def parse
      @root_component = Elements::TextComponent.new(document, source, [], state.dup)
      @root_component.process

      reintroduce_trailing_and_leading_whitespace if @root_component.children
    end

    def render(prawn, renderer)
      return unless @root_component.children

      origin_x = @root_component.x_values.first
      origin_y = @root_component.y_values.first

      @root_component.lay_out(prawn)

      translate_x =
        case @root_component.computed_properties.text_anchor
        when 'middle'
          -@root_component.calculated_width / 2.0
        when 'end'
          -@root_component.calculated_width
        end

      cursor = Cursor.new(0, document.sizing.output_height)

      if vertical_writing_mode?
        render_vertical(prawn, renderer, cursor, translate_x, origin_x, origin_y)
      else
        @root_component.render_component(prawn, renderer, cursor, translate_x)
      end
    end

    private

    def vertical_writing_mode?
      wm = @root_component.computed_properties.writing_mode
      ['vertical-rl', 'vertical-lr'].include?(wm)
    end

    def render_vertical(prawn, renderer, cursor, translate_x, origin_x, origin_y)
      origin_x ||= 0
      origin_y ||= document.sizing.output_height

      prawn.rotate(-90, origin: [origin_x, origin_y]) do
        @root_component.render_component(prawn, renderer, cursor, translate_x)
      end
    end

    def reintroduce_trailing_and_leading_whitespace
      text_nodes = []
      build_text_node_queue(text_nodes, @root_component)

      remove_whitespace_only_text_nodes_and_start_and_end(text_nodes)
      remove_text_nodes_that_are_completely_empty(text_nodes)
      apportion_leading_and_trailing_spaces(text_nodes)
    end

    def build_text_node_queue(queue, component)
      return unless component.children

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
