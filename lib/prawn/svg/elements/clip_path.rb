class Prawn::SVG::Elements::ClipPath < Prawn::SVG::Elements::Base
  def parse
    state.inside_clip_path = true
    set_display_none
  end

  def container?
    true
  end

  # process_child_elements wraps each child's calls in save and restore, so count the non-empty pairs.
  def drawn_child_count
    depth = 0
    calls.each_cons(2).count do |(call, *), (next_call, *)|
      depth += 1 if call == 'save'
      depth -= 1 if call == 'restore'
      call == 'save' && depth == 1 && next_call != 'restore'
    end
  end

  def build_clip_calls(element)
    units = attributes['clipPathUnits'] || 'userSpaceOnUse'

    if units == 'objectBoundingBox'
      bbox = element.bounding_box
      if bbox.nil?
        document.add_issue(:unsupported, 'clipPath with clipPathUnits="objectBoundingBox" requires element to have a bounding box')
        return nil
      end

      build_object_bounding_box_calls(bbox)
    else
      duplicate_calls(base_calls)
    end
  end
end
