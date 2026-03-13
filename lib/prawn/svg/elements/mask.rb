class Prawn::SVG::Elements::Mask < Prawn::SVG::Elements::Base
  def parse
    set_display_none
  end

  def container?
    true
  end

  def build_mask_calls(element)
    bbox = element.bounding_box
    mask_units = attributes['maskUnits'] || 'objectBoundingBox'
    content_units = attributes['maskContentUnits'] || 'userSpaceOnUse'

    if content_units == 'objectBoundingBox' && bbox.nil?
      document.warnings << 'mask with maskContentUnits="objectBoundingBox" requires element to have a bounding box'
      return []
    end

    calls = []

    calls.concat(build_clip_calls(bbox, mask_units)) if bbox || mask_units == 'userSpaceOnUse'

    if content_units == 'objectBoundingBox'
      calls.concat(build_object_bounding_box_calls(bbox))
    else
      calls.concat(duplicate_calls(base_calls))
    end

    calls
  end

  private

  def build_clip_calls(bbox, mask_units)
    if mask_units == 'objectBoundingBox'
      mask_x = Float(attributes['x'] || '-0.1')
      mask_y = Float(attributes['y'] || '-0.1')
      mask_w = Float(attributes['width'] || '1.2')
      mask_h = Float(attributes['height'] || '1.2')

      bbox_left = bbox[0]
      bbox_top = bbox[1]
      bbox_right = bbox[2]
      bbox_bottom = bbox[3]
      bbox_w = bbox_right - bbox_left
      bbox_h = bbox_top - bbox_bottom

      clip_left = bbox_left + (mask_x * bbox_w)
      clip_top = bbox_top - (mask_y * bbox_h)
      clip_width = mask_w * bbox_w
      clip_height = mask_h * bbox_h
    else
      clip_left = x_pixels(attributes['x'] || '-10%')
      clip_top = y(attributes['y'] || '-10%')
      clip_width = x_pixels(attributes['width'] || '120%')
      clip_height = y_pixels(attributes['height'] || '120%')
    end

    [
      ['rectangle', [[clip_left, clip_top], clip_width, clip_height], {}, []],
      ['clip', [], {}, []]
    ]
  end
end
