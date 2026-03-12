class Prawn::SVG::Elements::Pattern < Prawn::SVG::Elements::Base
  attr_reader :parent_pattern

  def parse
    raise SkipElementQuietly if attributes['id'].nil?

    @parent_pattern = document.gradients[href_attribute[1..]] if href_attribute && href_attribute[0] == '#'

    properties.display = 'none'
    computed_properties.display = 'none'

    document.gradients[attributes['id']] = self
  end

  def container?
    true
  end

  def pattern_arguments(element)
    bbox = element.bounding_box
    units = derive_attribute('patternUnits') || 'objectBoundingBox'
    content_units = derive_attribute('patternContentUnits') || 'userSpaceOnUse'
    view_box_attr = derive_attribute('viewBox')
    par_attr = derive_attribute('preserveAspectRatio')

    tile = compute_tile(units, bbox)
    return nil unless tile

    tile_x, tile_y_bottom, tile_w, tile_h = tile

    transform = Matrix.identity(3)
    if (transform_attr = derive_attribute('patternTransform'))
      transform = parse_transform_attribute(transform_attr, space: :svg)
    end

    content_calls = build_content_calls(content_units, view_box_attr, par_attr, tile_w, tile_h, bbox, units, tile_x, tile_y_bottom)
    return nil if content_calls.nil?

    {
      tile_x:      tile_x,
      tile_y:      tile_y_bottom,
      tile_width:  tile_w,
      tile_height: tile_h,
      transform:   transform,
      calls:       content_calls
    }
  end

  def derive_attribute(name)
    attributes[name] || parent_pattern&.derive_attribute(name)
  end

  private

  def compute_tile(units, bbox)
    if units == 'objectBoundingBox'
      return nil unless bbox

      x_frac = percentage_or_proportion(derive_attribute('x'), 0.0)
      y_frac = percentage_or_proportion(derive_attribute('y'), 0.0)
      w_frac = percentage_or_proportion(derive_attribute('width'), 0.0)
      h_frac = percentage_or_proportion(derive_attribute('height'), 0.0)

      return nil if w_frac <= 0 || h_frac <= 0

      bbox_left, bbox_top, bbox_right, bbox_bottom = *bbox
      bbox_w = bbox_right - bbox_left
      bbox_h = bbox_top - bbox_bottom

      tile_w = w_frac * bbox_w
      tile_h = h_frac * bbox_h
      tile_x = bbox_left + (x_frac * bbox_w)
      tile_y_top = bbox_top - (y_frac * bbox_h)
      tile_y_bottom = tile_y_top - tile_h

    else
      tile_x = x_pixels(derive_attribute('x') || '0')
      tile_y_svg = y_pixels(derive_attribute('y') || '0')
      tile_w = x_pixels(derive_attribute('width') || '0')
      tile_h = y_pixels(derive_attribute('height') || '0')

      return nil if tile_w <= 0 || tile_h <= 0

      tile_y_bottom = document.sizing.output_height - tile_y_svg - tile_h

    end
    [tile_x, tile_y_bottom, tile_w, tile_h]
  end

  def build_content_calls(content_units, view_box_attr, par_attr, tile_w, tile_h, bbox, units, tile_x, tile_y_bottom)
    if view_box_attr
      build_viewbox_content_calls(view_box_attr, par_attr, tile_w, tile_h)
    elsif content_units == 'objectBoundingBox'
      return nil unless bbox

      build_object_bounding_box_content_calls(bbox)
    else
      calls = content_source_calls
      shift_content_to_tile_origin(calls, units, tile_x, tile_y_bottom, tile_h)
    end
  end

  def build_viewbox_content_calls(view_box_attr, par_attr, tile_w, tile_h)
    vb_values = view_box_attr.strip.split(COMMA_WSP_REGEXP).map(&:to_f)
    return content_source_calls if vb_values.length != 4

    vb_x, vb_y, vb_w, vb_h = vb_values
    return content_source_calls if vb_w <= 0 || vb_h <= 0

    aspect = Prawn::SVG::Calculators::AspectRatio.new(par_attr, [tile_w, tile_h], [vb_w, vb_h])

    x_scale = aspect.width / vb_w
    y_scale = aspect.height / vb_h

    calls = []
    calls << ['transformation_matrix', [x_scale, 0, 0, y_scale, 0, 0], {}, []]
    calls << ['transformation_matrix', [1, 0, 0, 1, -vb_x + (aspect.x / x_scale), vb_y - (aspect.y / y_scale)], {}, []]
    calls.concat(content_source_calls)
    calls
  end

  def build_object_bounding_box_content_calls(bbox)
    bbox_left, bbox_top, bbox_right, bbox_bottom = *bbox
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

      container = Prawn::SVG::Elements::Container.new(document, content_source, [], new_state)
      container.process

      container.base_calls
    end

    scale_calls_to_bbox(duplicate_calls(result_calls), bbox_left, bbox_top, bbox_w, bbox_h)
  end

  # SVG spec: pattern content coordinates have their origin at the pattern's (x,y).
  # Since prawn-svg processes children in document coordinates, we shift the content
  # to the tile origin so it fills the pattern BBox correctly.
  def shift_content_to_tile_origin(calls, units, tile_x, tile_y_bottom, tile_h)
    if units == 'userSpaceOnUse'
      tile_y_svg = document.sizing.output_height - tile_y_bottom - tile_h
      return calls if tile_x.zero? && tile_y_svg.zero?

      [['transformation_matrix', [1, 0, 0, 1, tile_x, -tile_y_svg], {}, calls]]
    else
      calls
    end
  end

  def content_source
    if parent_pattern && source.elements.none? { |e| ['', SVG_NAMESPACE].include?(e.namespace) }
      parent_pattern.send(:content_source)
    else
      source
    end
  end

  def content_source_calls
    if parent_pattern && base_calls.empty?
      duplicate_calls(parent_pattern.base_calls)
    else
      duplicate_calls(base_calls)
    end
  end

  def percentage_or_proportion(string, default = 0)
    string = string.to_s.strip
    percentage = false

    if string[-1] == '%'
      percentage = true
      string = string[0..-2]
    end

    value = Float(string, exception: false)
    return default unless value

    percentage ? value / 100.0 : value
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
