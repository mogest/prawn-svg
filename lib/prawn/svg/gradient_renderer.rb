class Prawn::SVG::GradientRenderer
  include Prawn::SVG::PDFMatrix

  @mutex = Mutex.new
  @counter = 0

  def initialize(prawn, draw_type, from:, to:, stops:, matrix: nil, r1: nil, r2: nil, wrap: :pad, bounding_box: nil)
    @prawn = prawn
    @draw_type = draw_type
    @from = from
    @to = to
    @bounding_box = bounding_box

    if r1
      @shading_type = 3
      @coordinates = [*from, r1, *to, r2]
    else
      @shading_type = 2
      @coordinates = [*from, *to]
    end

    @stop_offsets, @color_stops, @opacity_stops = process_stop_arguments(stops)
    @gradient_matrix = matrix ? load_matrix(matrix) : Matrix.identity(3)
    @wrap = wrap
  end

  def draw
    key = self.class.next_key

    # If we need transparency, add an ExtGState to the page and enable it.
    if opacity_stops
      prawn.page.ext_gstates["PSVG-ExtGState-#{key}"] = create_transparency_graphics_state
      prawn.renderer.add_content("/PSVG-ExtGState-#{key} gs")
    end

    # Add pattern to the PDF page resources dictionary.
    prawn.page.resources[:Pattern] ||= {}
    prawn.page.resources[:Pattern]["PSVG-Pattern-#{key}"] = create_gradient_pattern

    # Finally set the pattern with the drawing operator for fill/stroke.
    prawn.send(:set_color_space, draw_type, :Pattern)
    draw_operator = draw_type == :fill ? 'scn' : 'SCN'
    prawn.renderer.add_content("/PSVG-Pattern-#{key} #{draw_operator}")
  end

  def self.next_key
    @mutex.synchronize { @counter += 1 }
  end

  private

  attr_reader :prawn, :draw_type, :shading_type, :coordinates, :from, :to,
    :stop_offsets, :color_stops, :opacity_stops, :gradient_matrix, :wrap, :bounding_box

  def process_stop_arguments(stops)
    stop_offsets = []
    color_stops = []
    opacity_stops = []

    transparency = false

    stops.each do |stop|
      opacity = stop[:opacity] || 1.0

      transparency = true if opacity < 1

      stop_offsets << stop[:offset]
      color_stops << prawn.send(:normalize_color, stop[:color])
      opacity_stops << [opacity]
    end

    opacity_stops = nil unless transparency

    [stop_offsets, color_stops, opacity_stops]
  end

  def create_transparency_graphics_state
    prawn.renderer.min_version(1.4)

    repeat_count, repeat_offset, transform = compute_wrapping(wrap, from, to, current_pdf_translation)

    x0, y0, x1, y1 = bounding_box || prawn_bounding_box

    offset_x, offset_y = prawn.bounds.anchor
    x0 += offset_x
    y0 += offset_y
    x1 += offset_x
    y1 += offset_y

    width = x1 - x0
    height = y0 - y1

    transparency_group = prawn.ref!(
      Type:      :XObject,
      Subtype:   :Form,
      BBox:      [x0, y1, x1, y0],
      Group:     {
        Type: :Group,
        S:    :Transparency,
        I:    true,
        CS:   :DeviceGray
      },
      Resources: {
        Pattern: {
          'TGP01' => {
            PatternType: 2,
            Matrix:      matrix_for_pdf(transform),
            Shading:     {
              ShadingType: shading_type,
              ColorSpace:  :DeviceGray,
              Coords:      coordinates,
              Domain:      [0, repeat_count],
              Function:    create_shading_function(stop_offsets, opacity_stops, wrap, repeat_count, repeat_offset),
              Extend:      [true, true]
            }
          }
        }
      }
    )

    transparency_group.stream << begin
      box = PDF::Core.real_params([x0, y1, width, height])

      <<~CMDS.strip
        /Pattern cs
        /TGP01 scn
        #{box} re
        f
      CMDS
    end

    prawn.ref!(
      Type:  :ExtGState,
      SMask: {
        Type: :Mask,
        S:    :Luminosity,
        G:    transparency_group
      },
      AIS:   false
    )
  end

  def create_gradient_pattern
    repeat_count, repeat_offset, transform = compute_wrapping(wrap, from, to, current_pdf_transform)

    prawn.ref!(
      PatternType: 2,
      Matrix:      matrix_for_pdf(transform),
      Shading:     {
        ShadingType: shading_type,
        ColorSpace:  prawn.send(:color_space, color_stops.first),
        Coords:      coordinates,
        Domain:      [0, repeat_count],
        Function:    create_shading_function(stop_offsets, color_stops, wrap, repeat_count, repeat_offset),
        Extend:      [true, true]
      }
    )
  end

  def create_shading_function(offsets, stop_values, wrap = :pad, repeat_count = 1, repeat_offset = 0)
    gradient_func = create_shading_function_for_stops(offsets, stop_values)

    # Return the gradient function if there is no need to repeat.
    return gradient_func if wrap == :pad

    even_odd_encode = wrap == :reflect ? [[0, 1], [1, 0]] : [[0, 1], [0, 1]]
    encode = repeat_count.times.flat_map { |num| even_odd_encode[(num + repeat_offset) % 2] }

    prawn.ref!(
      FunctionType: 3, # stitching function
      Domain:       [0, repeat_count],
      Functions:    Array.new(repeat_count, gradient_func),
      Bounds:       Range.new(1, repeat_count - 1).to_a,
      Encode:       encode
    )
  end

  def create_shading_function_for_stops(offsets, stop_values)
    linear_funcs = stop_values.each_cons(2).map do |c0, c1|
      prawn.ref!(FunctionType: 2, Domain: [0.0, 1.0], C0: c0, C1: c1, N: 1.0)
    end

    # If there's only two stops, we can use the single shader.
    return linear_funcs.first if linear_funcs.length == 1

    # Otherwise we stitch the multiple shaders together.
    prawn.ref!(
      FunctionType: 3, # stitching function
      Domain:       [0.0, 1.0],
      Functions:    linear_funcs,
      Bounds:       offsets[1..-2],
      Encode:       [0.0, 1.0] * linear_funcs.length
    )
  end

  def current_pdf_transform
    @current_pdf_transform ||= load_matrix(
      prawn.current_transformation_matrix_with_translation(*prawn.bounds.anchor)
    )
  end

  def current_pdf_translation
    @current_pdf_translation ||= begin
      bounds_x, bounds_y = prawn.bounds.anchor
      Matrix[[1, 0, bounds_x], [0, 1, bounds_y], [0, 0, 1]]
    end
  end

  def bounding_box_corners(matrix)
    if bounding_box
      transformed_corners(gradient_matrix.inverse, *bounding_box)
    else
      transformed_corners(matrix.inverse, *prawn_bounding_box)
    end
  end

  def prawn_bounding_box
    [*prawn.bounds.top_left, *prawn.bounds.bottom_right]
  end

  def transformed_corners(matrix, left, top, right, bottom)
    [
      matrix * Vector[left, top, 1.0],
      matrix * Vector[left, bottom, 1.0],
      matrix * Vector[right, top, 1.0],
      matrix * Vector[right, bottom, 1.0]
    ]
  end

  def compute_wrapping(wrap, from, to, page_transform)
    matrix = page_transform * gradient_matrix

    return [1, 0, matrix] if wrap == :pad

    from = Vector[from[0], from[1], 1.0]
    to = Vector[to[0], to[1], 1.0]

    # Transform the bounding box into gradient space where lines are straight
    # and circles are round.
    box_corners = bounding_box_corners(matrix)

    repeat_count, repeat_offset, delta = if shading_type == 2 # Linear
                                           project_bounding_box_for_linear(from, to, box_corners)
                                         else # Radial
                                           project_bounding_box_for_radial(from, to, box_corners)
                                         end

    repeat_count = [repeat_count, 50].min

    wrap_transform = translation_matrix(delta[0], delta[1]) *
                     translation_matrix(from[0], from[1]) *
                     scale_matrix(repeat_count) *
                     translation_matrix(-from[0], -from[1])

    [repeat_count, repeat_offset, matrix * wrap_transform]
  end

  def project_bounding_box_for_linear(from, to, box_corners)
    ab = to - from

    # Project each corner of the bounding box onto the line made by the
    # gradient. The formula for projecting a point C onto a line formed from
    # point A to point B is as follows:
    #
    # AB = B - A
    # AC = C - A
    # t = (AB dot AC) / (AB dot AB)
    # P = A + (AB * t)
    #
    # We don't actually need the final point P, we only need the parameter "t",
    # so that we know how many times to repeat the gradient.
    t_for_corners = box_corners.map do |corner|
      ac = corner - from
      ab.dot(ac) / ab.dot(ab)
    end

    t_min, t_max = t_for_corners.minmax

    repeat_count = (t_max - t_min).ceil + 1

    shift_count = t_min.floor
    delta = ab * shift_count
    repeat_offset = shift_count % 2

    [repeat_count, repeat_offset, delta]
  end

  def project_bounding_box_for_radial(from, to, box_corners)
    r1 = coordinates[2]
    r2 = coordinates[5]

    # For radial gradients, the approach is similar. We need to find "t" to
    # know how far along the gradient line each corner of the bounding box
    # lies. Only this time we need to solve the simultaneous equation for the
    # point on both inner and outer circles.
    #
    # You can find the derivation for this here:
    # https://github.com/libpixman/pixman/blob/85467ec308f8621a5410c007491797b7b1847601/pixman/pixman-radial-gradient.c#L162-L241
    #
    # Do this for all 4 corners and pick the biggest number to repeat.
    t = box_corners.reduce(1) do |max, corner|
      cdx, cdy = *(to - from)
      pdx, pdy = *(corner - from)
      dr = r2 - r1

      a = cdx.abs2 + cdy.abs2 - dr.abs2
      b = (pdx * cdx) + (pdy * cdy) + (r1 * dr)
      c = pdx.abs2 + pdy.abs2 - r1.abs2
      det_root = Math.sqrt(b.abs2 - (a * c))

      t0 = (b + det_root) / a
      t1 = (b - det_root) / a

      [t0, t1, max].max
    end

    repeat_count = t.ceil

    delta = [0.0, 0.0]
    repeat_offset = 0

    [repeat_count, repeat_offset, delta]
  end
end
