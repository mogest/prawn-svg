class Prawn::SVG::Elements::Mask < Prawn::SVG::Elements::Base
  def parse
    properties.display = 'none'
    computed_properties.display = 'none'
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

  def build_object_bounding_box_calls(bbox)
    bbox_left = bbox[0]
    bbox_top = bbox[1]
    bbox_right = bbox[2]
    bbox_bottom = bbox[3]
    bbox_w = bbox_right - bbox_left
    bbox_h = bbox_top - bbox_bottom

    # Prawn's soft_mask doesn't support transformation_matrix inside the block,
    # so we must produce calls with final Prawn coordinates.
    #
    # Set up sizing so that:
    # - viewport = 1x1 (objectBoundingBox fractions resolve as-is for unitless values)
    # - output_height = bbox_top, so y(frac) = bbox_top - frac = correct when bbox_h=1
    #
    # Then scale x by bbox_w, offset x by bbox_left, and scale y displacement by bbox_h.

    unit_sizing = Prawn::SVG::Calculators::DocumentSizing.new([1, 1])
    unit_sizing.document_width = 1
    unit_sizing.document_height = 1
    unit_sizing.calculate

    result_calls = document.with_sizing(unit_sizing) do
      new_state = state.dup
      new_state.viewport_sizing = unit_sizing
      new_state.inside_use = true

      container = Prawn::SVG::Elements::Container.new(document, source, [], new_state)
      container.process

      container.base_calls
    end

    scale_calls_to_bbox(duplicate_calls(result_calls), bbox_left, bbox_top, bbox_w, bbox_h)
  end

  def scale_calls_to_bbox(calls, bbox_left, bbox_top, bbox_w, bbox_h)
    calls.map do |name, args, kwargs, children|
      new_args = case name
                 when 'rectangle'
                   point, width, height = args
                   [scale_point(point, bbox_left, bbox_top, bbox_w, bbox_h), width * bbox_w, height * bbox_h]
                 when 'rounded_rectangle'
                   point, width, height, radius = args
                   [scale_point(point, bbox_left, bbox_top, bbox_w, bbox_h), width * bbox_w, height * bbox_h, radius * bbox_w]
                 when 'move_to', 'line_to'
                   [scale_point(args[0], bbox_left, bbox_top, bbox_w, bbox_h)]
                 when 'circle'
                   point, radius = args
                   scaled_point = scale_point(point, bbox_left, bbox_top, bbox_w, bbox_h)
                   if bbox_w == bbox_h
                     [scaled_point, radius * bbox_w]
                   else
                     new_children = children.any? ? scale_calls_to_bbox(children, bbox_left, bbox_top, bbox_w, bbox_h) : children
                     next ['ellipse', [scaled_point, radius * bbox_w, radius * bbox_h], kwargs, new_children]
                   end
                 when 'ellipse'
                   point, rx, ry = args
                   [scale_point(point, bbox_left, bbox_top, bbox_w, bbox_h), rx * bbox_w, ry * bbox_h]
                 when 'curve_to'
                   dest = scale_point(args[0], bbox_left, bbox_top, bbox_w, bbox_h)
                   [dest]
                 else
                   args
                 end

      new_kwargs = if name == 'curve_to' && kwargs[:bounds]
                     b = kwargs[:bounds]
                     { bounds: b.map { |p| scale_point(p, bbox_left, bbox_top, bbox_w, bbox_h) } }
                   else
                     kwargs
                   end

      new_children = children.any? ? scale_calls_to_bbox(children, bbox_left, bbox_top, bbox_w, bbox_h) : children
      [name, new_args, new_kwargs, new_children]
    end
  end

  def scale_point(point, bbox_left, bbox_top, bbox_w, bbox_h)
    # point is [x, 1.0 - svg_y] from unit sizing where output_height = 1
    # We need [bbox_left + svg_x * bbox_w, bbox_top - svg_y * bbox_h]
    # svg_x = point[0], svg_y = 1.0 - point[1]
    x = bbox_left + (point[0] * bbox_w)
    y = bbox_top - ((1.0 - point[1]) * bbox_h)
    [x, y]
  end
end
