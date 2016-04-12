class Prawn::SVG::Elements::Marker < Prawn::SVG::Elements::Base
  def parse
    raise SkipElementQuietly # we don't want anything pushed onto the call stack
  end

  def apply_marker(element, point: nil, angle: 0)
    return if element.state.display == 'none'

    sizing = Prawn::SVG::Calculators::DocumentSizing.new([0, 0], attributes)
    sizing.document_width = attributes["markerwidth"] || 3
    sizing.document_height = attributes["markerheight"] || 3
    sizing.calculate

    if sizing.invalid?
      document.warnings << "<marker> cannot be rendered due to invalid sizing information"
      return
    end

    element.new_call_context_from_base do
      element.add_call 'save'

      # LATER : these will probably change when we separate out properties from attributes
      element.parse_transform_attribute_and_call
      element.parse_opacity_attributes_and_call
      element.parse_clip_path_attribute_and_call

      element.add_call 'transformation_matrix', 1, 0, 0, 1, point[0], -point[1]

      if attributes['orient'] != 'auto'
        angle = attributes['orient'].to_f # defaults to 0 if not specified
      end

      element.add_call_and_enter 'rotate', -angle, origin: [0, y('0')] if angle != 0

      if attributes['markerunits'] != 'userSpaceOnUse'
        scale = element.state.stroke_width
        element.add_call 'transformation_matrix', scale, 0, 0, scale, 0, 0
      end

      ref_x = document.distance(attributes['refx']) || 0
      ref_y = document.distance(attributes['refy']) || 0

      element.add_call 'transformation_matrix', 1, 0, 0, 1, -ref_x * sizing.x_scale, ref_y * sizing.y_scale

      # `overflow: visible` must be on the <marker> element
      if attributes['overflow'] != 'visible'
        point = [sizing.x_offset * sizing.x_scale, y(sizing.y_offset * sizing.y_scale)]
        element.add_call "rectangle", point, sizing.output_width, sizing.output_height
        element.add_call "clip"
      end

      element.add_call 'transformation_matrix', sizing.x_scale, 0, 0, sizing.y_scale, 0, 0

      element.add_call_and_enter 'fill'
      element.add_call 'fill_color', '000000'

      # TODO : process attributes on <marker> element (and ancestors???), not just its children
      # but ignore 'display' attribute on marker
      element.process_child_elements(xml_elements: source.elements, base_state: Prawn::SVG::State.new)

      element.add_call 'restore'
    end
  end
end
