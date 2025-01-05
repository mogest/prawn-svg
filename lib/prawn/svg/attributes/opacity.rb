module Prawn::SVG::Attributes::Opacity
  def parse_opacity_attributes_and_call
    # The opacity property is not inherited, but the opacity applies to all children underneath the element.
    #
    # Having an opacity property on a parent, and again on a child, multiplies the parent and child's opacities
    # when drawing the children.
    #
    # The fill-opacity and stroke-opacity properties are inherited, but children which have a different value
    # are displayed at that opacity rather than multiplying the parent's fill/stroke opacity with the child's.
    #
    # opacity and fill/stroke opacity can both be applied to the same element, and they multiply together.

    opacity = computed_properties.opacity&.to_f&.clamp(0, 1)
    fill_opacity = computed_properties.fill_opacity.to_f.clamp(0, 1)
    stroke_opacity = computed_properties.stroke_opacity.to_f.clamp(0, 1)

    state.opacity *= opacity if opacity

    fill_opacity = (fill_opacity || 1) * state.opacity
    stroke_opacity = (stroke_opacity || 1) * state.opacity

    fill_opacity = stroke_opacity = 0 if computed_properties.visibility != 'visible'

    if state.last_fill_opacity != fill_opacity || state.last_stroke_opacity != stroke_opacity
      state.last_fill_opacity = fill_opacity
      state.last_stroke_opacity = stroke_opacity
      add_call_and_enter 'transparent', fill_opacity, stroke_opacity
    end
  end
end
