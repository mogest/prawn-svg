class Prawn::SVG::State
  attr_accessor :disable_drawing,
    :text_relative, :text_x_positions, :text_y_positions, :preserve_space,
    :fill_opacity, :stroke_opacity, :stroke_width,
    :fill, :stroke,
    :computed_properties

  def initialize
    @fill = true
    @stroke = false
    @stroke_width = 1
    @fill_opacity = 1
    @stroke_opacity = 1
    @computed_properties = Prawn::SVG::Properties.new.load_default_stylesheet
  end

  def initialize_dup(other)
    @computed_properties = @computed_properties.dup
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
