module Prawn::SVG::Attributes::Opacity
  def parse_opacity_attributes_and_call
    # We can't do nested opacities quite like the SVG requires, but this is close enough.
    opacity = properties.opacity.to_f.clamp(0, 1) if properties.opacity
    fill_opacity = properties.fill_opacity.to_f.clamp(0, 1) if properties.fill_opacity
    stroke_opacity = properties.stroke_opacity.to_f.clamp(0, 1) if properties.stroke_opacity

    if opacity || fill_opacity || stroke_opacity
      state.fill_opacity *= [opacity || 1, fill_opacity || 1].min
      state.stroke_opacity *= [opacity || 1, stroke_opacity || 1].min

      add_call_and_enter 'transparent', state.fill_opacity, state.stroke_opacity
    end
  end
end
