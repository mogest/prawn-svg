class Prawn::SVG::Elements::Gradient < Prawn::SVG::Elements::Base
  attr_reader :parent_gradient
  attr_reader :x1, :y1, :x2, :y2, :cx, :cy, :r, :fx, :fy, :fr, :units, :stops, :transform_matrix, :wrap

  TAG_NAME_TO_TYPE = {
    'linearGradient' => :linear,
    'radialGradient' => :radial
  }.freeze

  def parse
    # A gradient tag without an ID is inaccessible and can never be used
    raise SkipElementQuietly if attributes['id'].nil?

    @parent_gradient = document.gradients[href_attribute[1..]] if href_attribute && href_attribute[0] == '#'
    @transform_matrix = Matrix.identity(3)
    @wrap = :pad

    assert_compatible_prawn_version
    load_gradient_configuration
    load_coordinates
    load_stops

    document.gradients[attributes['id']] = self

    raise SkipElementQuietly # we don't want anything pushed onto the call stack
  end

  def gradient_arguments(element)
    bbox = element.bounding_box

    stroke_width = element.stroke_width
    bbox_with_stroke = bbox&.zip([-stroke_width, stroke_width, stroke_width, -stroke_width])&.map(&:sum)

    if type == :radial
      {
        from:         [fx, fy],
        r1:           fr,
        to:           [cx, cy],
        r2:           r,
        stops:        stops,
        matrix:       matrix_for_bounding_box(bbox),
        wrap:         wrap,
        bounding_box: bbox_with_stroke
      }
    else
      {
        from:         [x1, y1],
        to:           [x2, y2],
        stops:        stops,
        matrix:       matrix_for_bounding_box(bbox),
        wrap:         wrap,
        bounding_box: bbox_with_stroke
      }
    end
  end

  def derive_attribute(name)
    attributes[name] || parent_gradient&.derive_attribute(name)
  end

  private

  def matrix_for_bounding_box(bbox)
    if bbox && units == :bounding_box
      bounding_x1, bounding_y1, bounding_x2, bounding_y2 = *bbox

      width = bounding_x2 - bounding_x1
      height = bounding_y1 - bounding_y2

      bounding_box_to_user_space_matrix = Matrix[
        [width, 0.0, bounding_x1],
        [0.0, height, document.sizing.output_height - bounding_y1],
        [0.0, 0.0, 1.0]
      ]

      svg_to_pdf_matrix * bounding_box_to_user_space_matrix * transform_matrix
    else
      svg_to_pdf_matrix * transform_matrix
    end
  end

  def svg_to_pdf_matrix
    @svg_to_pdf_matrix ||= Matrix[[1.0, 0.0, 0.0], [0.0, -1.0, document.sizing.output_height], [0.0, 0.0, 1.0]]
  end

  def type
    TAG_NAME_TO_TYPE.fetch(name)
  end

  def assert_compatible_prawn_version
    if (Prawn::VERSION.split('.').map(&:to_i) <=> [2, 2, 0]) == -1
      raise SkipElementError, "Prawn 2.2.0+ must be used if you'd like prawn-svg to render gradients"
    end
  end

  def load_gradient_configuration
    @units = derive_attribute('gradientUnits') == 'userSpaceOnUse' ? :user_space : :bounding_box

    if (transform = derive_attribute('gradientTransform'))
      @transform_matrix = parse_transform_attribute(transform, space: :svg)
    end

    if (spread_method = derive_attribute('spreadMethod'))
      spread_method = spread_method.to_sym
      @wrap = [:pad, :reflect, :repeat].include?(spread_method) ? spread_method : :pad
    end
  end

  def load_coordinates
    case [type, units]
    when [:linear, :bounding_box]
      @x1 = percentage_or_proportion(derive_attribute('x1'), 0.0)
      @y1 = percentage_or_proportion(derive_attribute('y1'), 0.0)
      @x2 = percentage_or_proportion(derive_attribute('x2'), 1.0)
      @y2 = percentage_or_proportion(derive_attribute('y2'), 0.0)

    when [:linear, :user_space]
      @x1 = x(derive_attribute('x1'))
      @y1 = y_pixels(derive_attribute('y1'))
      @x2 = x(derive_attribute('x2'))
      @y2 = y_pixels(derive_attribute('y2'))

    when [:radial, :bounding_box]
      @cx = percentage_or_proportion(derive_attribute('cx'), 0.5)
      @cy = percentage_or_proportion(derive_attribute('cy'), 0.5)
      @r = percentage_or_proportion(derive_attribute('r'), 0.5)
      @fx = percentage_or_proportion(derive_attribute('fx'), cx)
      @fy = percentage_or_proportion(derive_attribute('fy'), cy)
      @fr = percentage_or_proportion(derive_attribute('fr'), 0.0)

    when [:radial, :user_space]
      @cx = x(derive_attribute('cx') || '50%')
      @cy = y_pixels(derive_attribute('cy') || '50%')
      @r = pixels(derive_attribute('r') || '50%')
      @fx = x(derive_attribute('fx') || derive_attribute('cx'))
      @fy = y_pixels(derive_attribute('fy') || derive_attribute('cy'))
      @fr = pixels(derive_attribute('fr') || '0%')

    else
      raise 'unexpected type/unit system'
    end
  end

  def load_stops
    stop_elements = source.elements.map do |child|
      element = Prawn::SVG::Elements::Base.new(document, child, [], Prawn::SVG::State.new)
      element.process
      element
    end.select do |element|
      element.name == 'stop' && element.attributes['offset']
    end

    @stops = stop_elements.each_with_object([]) do |child, result|
      offset = percentage_or_proportion(child.attributes['offset']).clamp(0.0, 1.0)

      # Offsets must be strictly increasing (SVG 13.2.4)
      offset = result.last[:offset] if result.last && result.last[:offset] > offset

      if (color = child.properties.stop_color&.value)
        result << { offset: offset, color: color, opacity: (child.properties.stop_opacity || 1.0).clamp(0.0, 1.0) }
      end
    end

    if stops.empty?
      if parent_gradient.nil? || parent_gradient.stops.empty?
        raise SkipElementError, 'gradient does not have any valid stops'
      end

      @stops = parent_gradient.stops
    else
      if stops.first[:offset].positive?
        start_stop = stops.first.dup
        start_stop[:offset] = 0
        stops.unshift(start_stop)
      end

      if stops.last[:offset] < 1
        end_stop = stops.last.dup
        end_stop[:offset] = 1
        stops.push(end_stop)
      end
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

    if percentage
      value / 100.0
    else
      value
    end
  end
end
