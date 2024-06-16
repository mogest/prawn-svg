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
      else
        array = dasharray.split(Prawn::SVG::Elements::COMMA_WSP_REGEXP)
        array *= 2 if array.length.odd?
        number_array = array.map { |value| pixels(value) }

        if number_array.any?(&:negative?)
          @document.warnings << "stroke-dasharray cannot have negative numbers; treating as 'none'"
          add_call('undash')
        elsif number_array.inject(0) { |a, b| a + b }.zero?
          add_call('undash')
        else
          add_call('dash', number_array)
        end
      end
    end
  end
end
