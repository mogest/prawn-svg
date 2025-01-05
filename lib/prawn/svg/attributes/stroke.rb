module Prawn::SVG::Attributes::Stroke
  CAP_STYLE_TRANSLATIONS = { 'butt' => :butt, 'round' => :round, 'square' => :projecting_square }.freeze
  JOIN_STYLE_TRANSLATIONS = { 'miter' => :miter, 'round' => :round, 'bevel' => :bevel }.freeze

  def parse_stroke_attributes_and_call
    if (width_string = properties.stroke_width)
      width = pixels(width_string)
      state.stroke_width = width
      add_call('line_width', width)
    end

    if (linecap = properties.stroke_linecap) && linecap != 'inherit'
      add_call('cap_style', CAP_STYLE_TRANSLATIONS.fetch(linecap, :butt))
    end

    if (linejoin = properties.stroke_linejoin) && linejoin != 'inherit'
      add_call('join_style', JOIN_STYLE_TRANSLATIONS.fetch(linejoin, :miter))
    end

    if (dasharray = properties.stroke_dasharray)
      case dasharray
      when 'inherit'
        # don't do anything
      when 'none'
        add_call('undash')
      when Array
        dasharray *= 2 if dasharray.length.odd?
        values = dasharray.map { |value| pixels(value) }

        if values.inject(0) { |a, b| a + b }.zero?
          add_call('undash')
        else
          add_call('dash', values)
        end
      else
        raise "Unknown dasharray value: #{dasharray.inspect}"
      end
    end
  end
end
