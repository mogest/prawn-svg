class Prawn::SVG::Elements::Pattern < Prawn::SVG::Elements::Base
  attr_reader :parent_pattern

  def parse
    raise SkipElementQuietly if attributes['id'].nil?

    @parent_pattern = document.gradients[href_attribute[1..]] if href_attribute && href_attribute[0] == '#'

    set_display_none

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

      build_object_bounding_box_calls(bbox, content_source)
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
end
