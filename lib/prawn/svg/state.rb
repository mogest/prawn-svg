class Prawn::SVG::State
  attr_accessor :text, :preserve_space,
    :opacity, :last_fill_opacity, :last_stroke_opacity,
    :stroke_width,
    :computed_properties,
    :viewport_sizing,
    :inside_use, :inside_clip_path

  def initialize
    @stroke_width = 1
    @opacity = 1
    @last_fill_opacity = 1
    @last_stroke_opacity = 1
    @computed_properties = Prawn::SVG::Properties.new.load_default_stylesheet
  end

  def initialize_dup(_other)
    @computed_properties = @computed_properties.dup
  end

  def disable_drawing
    inside_clip_path
  end
end
