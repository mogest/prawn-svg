module Prawn::SVG::TransformParser
  include Prawn::SVG::PDFMatrix

  def parse_transform_attribute(transform, space: :pdf)
    matrix = Matrix.identity(3)

    flip = space == :svg ? 1.0 : -1.0

    parse_css_method_calls(transform).each do |name, arguments|
      case name
      when 'translate'
        x, y = arguments
        matrix *= translation_matrix(x_pixels(x.to_f), flip * y_pixels(y.to_f))

      when 'translateX'
        x = arguments.first
        matrix *= translation_matrix(x_pixels(x.to_f), 0.0)

      when 'translateY'
        y = arguments.first
        matrix *= translation_matrix(0.0, flip * y_pixels(y.to_f))

      when 'rotate'
        angle, x, y = arguments.collect(&:to_f)
        angle = angle * Math::PI / 180.0

        rotation = rotation_matrix(angle, space: space)

        case arguments.length
        when 1
          matrix *= rotation
        when 3
          matrix *= translation_matrix(x_pixels(x.to_f), flip * y_pixels(y.to_f))
          matrix *= rotation
          matrix *= translation_matrix(-x_pixels(x.to_f), -flip * y_pixels(y.to_f))
        else
          warnings << "transform 'rotate' must have either one or three arguments"
        end

      when 'scale'
        x_scale = arguments[0].to_f
        y_scale = (arguments[1] || x_scale).to_f
        matrix *= scale_matrix(x_scale, y_scale)

      when 'skewX'
        angle = arguments[0].to_f * Math::PI / 180.0
        matrix *= Matrix[[1, flip * Math.tan(angle), 0], [0, 1, 0], [0, 0, 1]]

      when 'skewY'
        angle = arguments[0].to_f * Math::PI / 180.0
        matrix *= Matrix[[1, 0, 0], [flip * Math.tan(angle), 1, 0], [0, 0, 1]]

      when 'matrix'
        if arguments.length == 6
          a, b, c, d, e, f = arguments.collect(&:to_f)
          matrix *= Matrix[[a, flip * c, e], [flip * b, d, flip * f], [0, 0, 1]]
        else
          warnings << "transform 'matrix' must have six arguments"
        end

      else
        warnings << "Unknown/unsupported transformation '#{name}'; ignoring"
      end
    end

    matrix
  end

  private

  def parse_css_method_calls(string)
    string.scan(/\s*(\w+)\(([^)]+)\)\s*/).collect do |call|
      name, argument_string = call
      arguments = argument_string.strip.split(/\s*[,\s]\s*/)
      [name, arguments]
    end
  end
end
