class Prawn::SVG::Elements::ClipPath < Prawn::SVG::Elements::Base
  def parse
    state.inside_clip_path = true
    properties.display = 'none'
    computed_properties.display = 'none'
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

  private

  def build_object_bounding_box_calls(bbox)
    bbox_left = bbox[0]
    bbox_top = bbox[1]
    bbox_right = bbox[2]
    bbox_bottom = bbox[3]
    bbox_w = bbox_right - bbox_left
    bbox_h = bbox_top - bbox_bottom

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
    x = bbox_left + (point[0] * bbox_w)
    y = bbox_top - ((1.0 - point[1]) * bbox_h)
    [x, y]
  end
end
