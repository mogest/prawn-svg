class Prawn::SVG::PatternRenderer
  include Prawn::SVG::PDFMatrix

  def initialize(prawn, draw_type, renderer, tile_x:, tile_y:, tile_width:, tile_height:, transform:, calls:)
    @prawn = prawn
    @draw_type = draw_type
    @renderer = renderer
    @tile_x = tile_x
    @tile_y = tile_y
    @tile_width = tile_width
    @tile_height = tile_height
    @transform = transform
    @calls = calls
  end

  def draw
    key = Prawn::SVG::GradientRenderer.next_key

    pattern_ref = create_tiling_pattern(key)

    prawn.page.resources[:Pattern] ||= {}
    prawn.page.resources[:Pattern]["PSVG-Pattern-#{key}"] = pattern_ref

    prawn.send(:set_color_space, draw_type, :Pattern)
    draw_operator = draw_type == :fill ? 'scn' : 'SCN'
    prawn.renderer.add_content("/PSVG-Pattern-#{key} #{draw_operator}")
  end

  private

  attr_reader :prawn, :draw_type, :renderer, :tile_x, :tile_y, :tile_width, :tile_height, :transform, :calls

  def create_tiling_pattern(key)
    stamp_name = "PSVG-PatternContent-#{key}"

    prawn.create_stamp(stamp_name) do
      renderer.render_calls(prawn, calls)
    end

    registry = prawn.instance_variable_get(:@stamp_dictionary_registry)
    stamp_entry = registry[stamp_name]
    stamp_dict = stamp_entry[:stamp_dictionary]

    # The content shift uses the base matrix (without patternTransform) so that
    # content fills the tile correctly. The pattern Matrix includes the transform
    # so the tiling grid is rotated/scaled, but each tile's content is not.
    base = base_pattern_matrix
    inverse = base.inverse

    pattern_ref = prawn.ref!(
      PatternType: 1,
      PaintType:   1,
      TilingType:  1,
      BBox:        [0, 0, tile_width, tile_height],
      XStep:       tile_width,
      YStep:       tile_height,
      Matrix:      matrix_for_pdf(full_pattern_matrix),
      Resources:   stamp_dict.data[:Resources] || {}
    )

    inv_pdf = matrix_for_pdf(inverse)
    cm_str = inv_pdf.map { |v| v.is_a?(Float) ? format('%.6f', v) : v.to_s }.join(' ')
    pattern_ref.stream << "#{cm_str} cm\n"
    pattern_ref.stream << stamp_dict.stream.filtered_stream

    registry.delete(stamp_name)

    pattern_ref
  end

  def svg_to_page_matrix
    bounds_x, bounds_y = prawn.bounds.anchor
    output_height = prawn.bounds.height

    Matrix[
      [1.0, 0.0, bounds_x.to_f],
      [0.0, -1.0, bounds_y.to_f + output_height],
      [0.0, 0.0, 1.0]
    ]
  end

  def pattern_to_svg_matrix
    output_height = prawn.bounds.height
    svg_x = tile_x.to_f
    svg_y = (output_height - tile_y - tile_height).to_f

    Matrix[
      [1.0, 0.0, svg_x],
      [0.0, -1.0, svg_y + tile_height],
      [0.0, 0.0, 1.0]
    ]
  end

  # Maps pattern space to page space WITHOUT patternTransform.
  # Used to shift stamp content (in page coords) to pattern-local coords.
  def base_pattern_matrix
    svg_to_page_matrix * pattern_to_svg_matrix
  end

  # Maps pattern space to page space WITH patternTransform and viewport scaling.
  # Used as the pattern's Matrix field so the tiling grid is transformed.
  # Viewport scaling is needed because stamp content is in SVG user units,
  # but shapes on the page are scaled by the document's viewport transform.
  def full_pattern_matrix
    viewport_scale = scale_matrix(sizing.x_scale, sizing.y_scale)
    svg_to_page_matrix * viewport_scale * transform * pattern_to_svg_matrix
  end

  def sizing
    renderer.document.sizing
  end
end
