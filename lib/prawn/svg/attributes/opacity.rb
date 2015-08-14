module Prawn::SVG::Attributes::Opacity
  def parse_opacity_attributes_and_call
    # We can't do nested opacities quite like the SVG requires, but this is close enough.
    fill_opacity = stroke_opacity = clamp(attributes['opacity'].to_f, 0, 1) if attributes['opacity']
    fill_opacity = clamp(attributes['fill-opacity'].to_f, 0, 1) if attributes['fill-opacity']
    stroke_opacity = clamp(attributes['stroke-opacity'].to_f, 0, 1) if attributes['stroke-opacity']

    if fill_opacity || stroke_opacity
      state[:fill_opacity] = (state[:fill_opacity] || 1) * (fill_opacity || 1)
      state[:stroke_opacity] = (state[:stroke_opacity] || 1) * (stroke_opacity || 1)

      add_call_and_enter 'transparent', state[:fill_opacity], state[:stroke_opacity]
    end
  end
end
