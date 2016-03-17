class Prawn::SVG::State
  attr_accessor :disable_drawing,
    :color, :display,
    :font_size, :font_weight, :font_style, :font_family, :font_subfamily,
    :text_anchor, :text_relative, :text_x_positions, :text_y_positions, :preserve_space,
    :fill_opacity, :stroke_opacity,
    :fill, :stroke

  def initialize
    @fill = true
    @stroke = false
    @fill_opacity = 1
    @stroke_opacity = 1
  end

  def enable_draw_type(type)
    case type
    when 'fill'   then @fill = true
    when 'stroke' then @stroke = true
    else raise
    end
  end

  def disable_draw_type(type)
    case type
    when 'fill'   then @fill = false
    when 'stroke' then @stroke = false
    else raise
    end
  end

  def draw_type(type)
    case type
    when 'fill'   then @fill
    when 'stroke' then @stroke
    else raise
    end
  end
end
