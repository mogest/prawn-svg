module Prawn::SVG
  class Elements::TextComponent < Elements::DirectRenderBase
    attr_reader :children, :parent_component
    attr_reader :x_values, :y_values, :dx, :dy, :rotation, :text_length, :length_adjust
    attr_reader :font

    def initialize(document, source, _calls, state, parent_component = nil)
      if parent_component.nil? && source.name != 'text'
        raise SkipElementError, 'attempted to <use> a component inside a text element, this is not supported'
      end

      super(document, source, [], state)
      @parent_component = parent_component
    end

    def parse
      raise SkipElementError, '<text> elements are not supported in clip paths' if state.inside_clip_path

      @x_values = parse_wsp('x').map { |n| x(n) }
      @y_values = parse_wsp('y').map { |n| y(n) }
      @dx = parse_wsp('dx').map { |n| x_pixels(n) }
      @dy = parse_wsp('dy').map { |n| y_pixels(n) }
      @rotation = parse_wsp('rotate').map(&:to_f)
      @text_length = normalize_length(attributes['textLength'])
      @length_adjust = attributes['lengthAdjust']

      @font = select_font

      @children = svg_text_children.flat_map do |child|
        if child.node_type == :text
          build_text_node(child)
        else
          case child.name
          when 'tspan', 'tref'
            build_child(child)
          else
            warnings << "Unknown tag '#{child.name}' inside text tag; ignoring"
            []
          end
        end
      end
    end

    def lay_out(prawn)
      @children.each do |child|
        prawn.save_font do
          prawn.font(font.name, style: font.subfamily) if font
          child.lay_out(prawn)
        end
      end

      if @text_length
        flexible_width, fixed_width = total_flexible_and_fixed_width

        if flexible_width.positive?
          target_width = [@text_length - fixed_width, 0].max
          factor = target_width / flexible_width
          apply_factor_to_base_width(factor)
        end
      end
    end

    def render_component(prawn, renderer, cursor, translate_x = nil)
      raise SkipElementQuietly if computed_properties.display == 'none'

      add_yield_call do
        prawn.translate(translate_x, 0) if translate_x

        size = computed_properties.numeric_font_size

        if computed_properties.dominant_baseline == 'middle'
          height = FontMetrics.x_height_in_points(prawn, size || prawn.font_size)
          y_offset = -height / 2.0
        end

        prawn.save_font do
          prawn.font(font.name, style: font.subfamily) if font

          children.each do |child|
            case child
            when Elements::TextNode
              child.render(prawn, size, cursor, y_offset)
            when self.class
              prawn.save_graphics_state
              child.render_component(prawn, renderer, cursor)
              prawn.restore_graphics_state
            else
              raise
            end
          end
        end
      end

      renderer.render_calls(prawn, base_calls)
    end

    def calculated_width
      children.reduce(0) { |total, child| total + child.calculated_width }
    end

    def current_length_adjust_is_scaling?
      if @text_length
        @length_adjust == 'spacingAndGlyphs'
      elsif parent_component
        parent_component.current_length_adjust_is_scaling?
      else
        false
      end
    end

    def letter_spacing_pixels
      if computed_properties.letter_spacing == 'normal'
        nil
      else
        x_pixels(computed_properties.letter_spacing)
      end
    end

    protected

    def build_text_node(child)
      if state.preserve_space
        text = child.value.tr("\n\t", ' ')
      else
        text = child.value.tr("\n", '').tr("\t", ' ')
        leading = text[0] == ' '
        trailing = text[-1] == ' '
        text = text.strip.gsub(/ {2,}/, ' ')
      end

      Elements::TextNode.new(self, text, leading, trailing)
    end

    def build_child(child)
      component = self.class.new(document, child, [], state.dup, self)
      component.process
      component
    end

    def svg_text_children
      text_children.select do |child|
        child.node_type == :text || (
          child.node_type == :element &&
            [SVG_NAMESPACE, ''].include?(child.namespace)

        )
      end
    end

    def text_children
      if name == 'tref'
        reference = find_referenced_element
        reference ? reference.source.children : []
      else
        source.children
      end
    end

    def find_referenced_element
      href = href_attribute

      if href && href[0..0] == '#'
        element = document.elements_by_id[href[1..]]
        element if element.name == 'text'
      end
    end

    def select_font
      font_families = [computed_properties.font_family, document.fallback_font_name]
      font_style = :italic if computed_properties.font_style == 'italic'
      font_weight = computed_properties.font_weight

      font_families.compact.each do |name|
        font = document.font_registry.load(name, font_weight, font_style)
        return font if font
      end

      warnings << "Font family '#{computed_properties.font_family}' style '#{computed_properties.font_style}' is not a known font, and the fallback font could not be found."
      nil
    end

    def total_flexible_and_fixed_width
      flexible = fixed = 0
      @children.each do |child|
        child.total_flexible_and_fixed_width.tap do |a, b|
          flexible += a
          fixed += b
        end
      end
      [flexible, fixed]
    end

    def apply_factor_to_base_width(factor)
      @children.each do |child|
        if child.is_a?(Elements::TextNode)
          child.chunks.reject(&:fixed_width).each do |chunk|
            chunk.fixed_width = chunk.base_width * factor
          end
        elsif child.is_a?(self.class)
          child.apply_factor_to_base_width(factor)
        else
          raise
        end
      end
    end

    # overridden from Base, we don't want to call fill/stroke as draw_text does this for us
    def apply_drawing_call; end

    # overridden from Base, transforms can't be applied to tspan elements
    def transformable?
      source.name != 'tspan'
    end

    # overridden from Base, we want the id to point to the Text element
    def add_to_elements_by_id?
      source.name != 'text'
    end

    def normalize_length(length)
      x_pixels(length) if length&.match(/\d/)
    end

    def parse_wsp(name)
      (attributes[name] || '').split(COMMA_WSP_REGEXP)
    end
  end
end
