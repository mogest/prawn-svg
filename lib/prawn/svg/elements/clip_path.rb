class Prawn::SVG::Elements::ClipPath < Prawn::SVG::Elements::Base
  def parse
    state.inside_clip_path = true
    set_display_none
  end

  def container?
    true
  end

  def build_clip_calls(element)
    units = attributes['clipPathUnits'] || 'userSpaceOnUse'

    if units == 'objectBoundingBox'
      bbox = element.bounding_box
      if bbox.nil?
        document.warnings << 'clipPath with clipPathUnits="objectBoundingBox" requires element to have a bounding box'
        return nil
      end

      build_object_bounding_box_calls(bbox)
    else
      duplicate_calls(base_calls)
    end
  end
end
