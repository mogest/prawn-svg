module Prawn::SVG::Attributes::Stroke
  CAP_STYLE_TRANSLATIONS = {"butt" => :butt, "round" => :round, "square" => :projecting_square}

  def parse_stroke_attributes_and_call
    if width = attributes['stroke-width']
      add_call('line_width', distance(width))
    end

    if (linecap = attribute_value_as_keyword('stroke-linecap')) && linecap != 'inherit'
      add_call('cap_style', CAP_STYLE_TRANSLATIONS.fetch(linecap, :butt))
    end

    if dasharray = attribute_value_as_keyword('stroke-dasharray')
      case dasharray
      when 'inherit'
        # don't do anything
      when 'none'
        add_call('undash')
      else
        array = dasharray.split(Prawn::SVG::Elements::COMMA_WSP_REGEXP)
        array *= 2 if array.length % 2 == 1
        number_array = array.map {|value| distance(value)}

        if number_array.any? {|number| number < 0}
          @document.warnings << "stroke-dasharray cannot have negative numbers; treating as 'none'"
          add_call('undash')
        elsif number_array.inject(0) {|a, b| a + b} == 0
          add_call('undash')
        else
          add_call('dash', number_array)
        end
      end
    end
  end
end
