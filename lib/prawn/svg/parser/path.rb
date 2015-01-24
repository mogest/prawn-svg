module Prawn
  module Svg
    class Parser::Path
      # Raised if the SVG path cannot be parsed.
      InvalidError = Class.new(StandardError)

      INSIDE_SPACE_REGEXP = /[ \t\r\n,]*/
      OUTSIDE_SPACE_REGEXP = /[ \t\r\n]*/
      INSIDE_REGEXP = /#{INSIDE_SPACE_REGEXP}([+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:(?<=[0-9])e[+-]?[0-9]+)?)/
      VALUES_REGEXP = /^#{INSIDE_REGEXP}/
      COMMAND_REGEXP = /^#{OUTSIDE_SPACE_REGEXP}([A-Za-z])((?:#{INSIDE_REGEXP})*)#{OUTSIDE_SPACE_REGEXP}/

      FLOAT_ERROR_DELTA = 1e-10

      #
      # Parses an SVG path and returns a Prawn-compatible call tree.
      #
      def parse(data)
        @subpath_initial_point = @last_point = nil
        @previous_control_point = @previous_quadratic_control_point = nil
        @calls = []

        data = data.gsub(/#{OUTSIDE_SPACE_REGEXP}$/, '')

        matched_commands = match_all(data, COMMAND_REGEXP)
        raise InvalidError, "Invalid/unsupported syntax for SVG path data" if matched_commands.nil?

        matched_commands.each do |matched_command|
          command = matched_command[1]
          matched_values = match_all(matched_command[2], VALUES_REGEXP)
          raise "should be impossible to have invalid inside data, but we ended up here" if matched_values.nil?
          values = matched_values.collect {|value| value[1].to_f}
          run_path_command(command, values)
        end

        @calls
      end


      private
      def run_path_command(command, values)
        upcase_command = command.upcase
        relative = command != upcase_command

        case upcase_command
        when 'M' # moveto
          x = values.shift
          y = values.shift

          if relative && @last_point
            x += @last_point.first
            y += @last_point.last
          end

          @last_point = @subpath_initial_point = [x, y]
          @calls << ["move_to", @last_point]

          return run_path_command(relative ? 'l' : 'L', values) if values.any?

        when 'Z' # closepath
          if @subpath_initial_point
            #@calls << ["line_to", @subpath_initial_point]
            @calls << ["close_path"]
            @last_point = @subpath_initial_point
          end

        when 'L' # lineto
          while values.any?
            x = values.shift
            y = values.shift
            if relative && @last_point
              x += @last_point.first
              y += @last_point.last
            end
            @last_point = [x, y]
            @calls << ["line_to", @last_point]
          end

        when 'H' # horizontal lineto
          while values.any?
            x = values.shift
            x += @last_point.first if relative && @last_point
            @last_point = [x, @last_point.last]
            @calls << ["line_to", @last_point]
          end

        when 'V' # vertical lineto
          while values.any?
            y = values.shift
            y += @last_point.last if relative && @last_point
            @last_point = [@last_point.first, y]
            @calls << ["line_to", @last_point]
          end

        when 'C' # curveto
          while values.any?
            x1, y1, x2, y2, x, y = (1..6).collect {values.shift}
            if relative && @last_point
              x += @last_point.first
              x1 += @last_point.first
              x2 += @last_point.first
              y += @last_point.last
              y1 += @last_point.last
              y2 += @last_point.last
            end

            @last_point = [x, y]
            @previous_control_point = [x2, y2]
            @calls << ["curve_to", [x, y, x1, y1, x2, y2]]
          end

        when 'S' # shorthand/smooth curveto
          while values.any?
            x2, y2, x, y = (1..4).collect {values.shift}
            if relative && @last_point
              x += @last_point.first
              x2 += @last_point.first
              y += @last_point.last
              y2 += @last_point.last
            end

            if @previous_control_point
              x1 = 2 * @last_point.first - @previous_control_point.first
              y1 = 2 * @last_point.last - @previous_control_point.last
            else
              x1, y1 = @last_point
            end

            @last_point = [x, y]
            @previous_control_point = [x2, y2]
            @calls << ["curve_to", [x, y, x1, y1, x2, y2]]
          end

        when 'Q', 'T' # quadratic curveto
          while values.any?
            if shorthand = upcase_command == 'T'
              x, y = (1..2).collect {values.shift}
            else
              x1, y1, x, y = (1..4).collect {values.shift}
            end

            if relative && @last_point
              x += @last_point.first
              x1 += @last_point.first if x1
              y += @last_point.last
              y1 += @last_point.last if y1
            end

            if shorthand
              if @previous_quadratic_control_point
                x1 = 2 * @last_point.first - @previous_quadratic_control_point.first
                y1 = 2 * @last_point.last - @previous_quadratic_control_point.last
              else
                x1, y1 = @last_point
              end
            end

            # convert from quadratic to cubic
            cx1 = @last_point.first + (x1 - @last_point.first) * 2 / 3.0
            cy1 = @last_point.last + (y1 - @last_point.last) * 2 / 3.0
            cx2 = cx1 + (x - @last_point.first) / 3.0
            cy2 = cy1 + (y - @last_point.last) / 3.0

            @last_point = [x, y]
            @previous_quadratic_control_point = [x1, y1]

            @calls << ["curve_to", [x, y, cx1, cy1, cx2, cy2]]
          end

        when 'A'
          return unless @last_point

          while values.any?
            rx, ry, phi, fa, fs, x2, y2 = (1..7).collect {values.shift}
            x1, y1 = @last_point

            return if rx.zero? && ry.zero?

            if relative
              x2 += x1
              y2 += y1
            end

            # Normalise values as per F.6.2
            rx = rx.abs
            ry = ry.abs
            phi = (phi % 360) * 2 * Math::PI / 360.0

            # F.6.2: If the endpoints (x1, y1) and (x2, y2) are identical, then this is equivalent to omitting the elliptical arc segment entirely.
            return if within_float_delta?(x1, x2) && within_float_delta?(y1, y2)

            # F.6.2: If rx = 0 or ry = 0 then this arc is treated as a straight line segment (a "lineto") joining the endpoints.
            if within_float_delta?(rx, 0) || within_float_delta?(ry, 0)
              @last_point = [x2, y2]
              @calls << ["line_to", @last_point]
              return
            end

            # We need to get the center co-ordinates, as well as the angles from the X axis to the start and end
            # points.  To do this, we use the algorithm documented in the SVG specification section F.6.5.

            # F.6.5.1
            xp1 = Math.cos(phi) * ((x1-x2)/2.0) + Math.sin(phi) * ((y1-y2)/2.0)
            yp1 = -Math.sin(phi) * ((x1-x2)/2.0) + Math.cos(phi) * ((y1-y2)/2.0)

            # F.6.6.2
            r2x = rx * rx
            r2y = ry * ry
            hat = xp1 * xp1 / r2x + yp1 * yp1 / r2y
            if hat > 1
              rx *= Math.sqrt(hat)
              ry *= Math.sqrt(hat)
            end

            # F.6.5.2
            r2x = rx * rx
            r2y = ry * ry
            square = (r2x * r2y - r2x * yp1 * yp1 - r2y * xp1 * xp1) / (r2x * yp1 * yp1 + r2y * xp1 * xp1)
            square = 0 if square < 0 && square > -FLOAT_ERROR_DELTA # catch rounding errors
            base = Math.sqrt(square)
            base *= -1 if fa == fs
            cpx = base * rx * yp1 / ry
            cpy = base * -ry * xp1 / rx

            # F.6.5.3
            cx = Math.cos(phi) * cpx + -Math.sin(phi) * cpy + (x1 + x2) / 2
            cy = Math.sin(phi) * cpx + Math.cos(phi) * cpy + (y1 + y2) / 2

            # F.6.5.5
            vx = (xp1 - cpx) / rx
            vy = (yp1 - cpy) / ry
            theta_1 = Math.acos(vx / Math.sqrt(vx * vx + vy * vy))
            theta_1 *= -1 if vy < 0

            # F.6.5.6
            ux = vx
            uy = vy
            vx = (-xp1 - cpx) / rx
            vy = (-yp1 - cpy) / ry

            numerator = ux * vx + uy * vy
            denominator = Math.sqrt(ux * ux + uy * uy) * Math.sqrt(vx * vx + vy * vy)
            division = numerator / denominator
            division = -1 if division < -1 # for rounding errors

            d_theta = Math.acos(division) % (2 * Math::PI)
            d_theta *= -1 if ux * vy - uy * vx < 0

            # Adjust range
            if fs == 0
              d_theta -= 2 * Math::PI if d_theta > 0
            else
              d_theta += 2 * Math::PI if d_theta < 0
            end

            theta_2 = theta_1 + d_theta

            calculate_bezier_curve_points_for_arc(cx, cy, rx, ry, theta_1, theta_2, phi).each do |points|
              @calls << ["curve_to", points[:p2] + points[:q1] + points[:q2]]
              @last_point = points[:p2]
            end
          end
        end

        @previous_control_point = nil unless %w(C S).include?(upcase_command)
        @previous_quadratic_control_point = nil unless %w(Q T).include?(upcase_command)
      end

      def within_float_delta?(a, b)
        (a - b).abs < FLOAT_ERROR_DELTA
      end

      def match_all(string, regexp) # regexp must start with ^
        result = []
        while string != ""
          matches = string.match(regexp)
          result << matches
          return if matches.nil?
          string = matches.post_match
        end
        result
      end

      def calculate_eta_from_lambda(a, b, lambda_1, lambda_2)
        # 2.2.1
        eta1 = Math.atan2(Math.sin(lambda_1) / b, Math.cos(lambda_1) / a)
        eta2 = Math.atan2(Math.sin(lambda_2) / b, Math.cos(lambda_2) / a)

        # ensure eta1 <= eta2 <= eta1 + 2*PI
        eta2 -= 2 * Math::PI * ((eta2 - eta1) / (2 * Math::PI)).floor
        eta2 += 2 * Math::PI if lambda_2 - lambda_1 > Math::PI && eta2 - eta1 < Math::PI

        [eta1, eta2]
      end

      # Convert the elliptical arc to a cubic bézier curve using this algorithm:
      # http://www.spaceroots.org/documents/ellipse/elliptical-arc.pdf
      def calculate_bezier_curve_points_for_arc(cx, cy, a, b, lambda_1, lambda_2, theta)
        e = lambda do |eta|
          [
            cx + a * Math.cos(theta) * Math.cos(eta) - b * Math.sin(theta) * Math.sin(eta),
            cy + a * Math.sin(theta) * Math.cos(eta) + b * Math.cos(theta) * Math.sin(eta)
          ]
        end

        ep = lambda do |eta|
          [
            -a * Math.cos(theta) * Math.sin(eta) - b * Math.sin(theta) * Math.cos(eta),
            -a * Math.sin(theta) * Math.sin(eta) + b * Math.cos(theta) * Math.cos(eta)
          ]
        end

        iterations = 1
        d_lambda = lambda_2 - lambda_1

        while iterations < 1024
          if d_lambda.abs <= Math::PI / 2.0
            # TODO : run error algorithm, see whether it meets threshold or not
            # puts "error = #{calculate_curve_approximation_error(a, b, eta1, eta1 + d_eta)}"
            break
          end
          iterations *= 2
          d_lambda = (lambda_2 - lambda_1) / iterations
        end

        (0...iterations).collect do |iteration|
          eta_a, eta_b = calculate_eta_from_lambda(a, b, lambda_1+iteration*d_lambda, lambda_1+(iteration+1)*d_lambda)
          d_eta = eta_b - eta_a

          alpha = Math.sin(d_eta) * ((Math.sqrt(4 + 3 * Math.tan(d_eta / 2) ** 2) - 1) / 3)

          x1, y1 = e[eta_a]
          x2, y2 = e[eta_b]

          ep_eta1_x, ep_eta1_y = ep[eta_a]
          q1_x = x1 + alpha * ep_eta1_x
          q1_y = y1 + alpha * ep_eta1_y

          ep_eta2_x, ep_eta2_y = ep[eta_b]
          q2_x = x2 - alpha * ep_eta2_x
          q2_y = y2 - alpha * ep_eta2_y

          {:p2 => [x2, y2], :q1 => [q1_x, q1_y], :q2 => [q2_x, q2_y]}
        end
      end

      ERROR_COEFFICIENTS_A = [
        [
          [3.85268, -21.229, -0.330434, 0.0127842],
          [-1.61486, 0.706564, 0.225945, 0.263682],
          [-0.910164, 0.388383, 0.00551445, 0.00671814],
          [-0.630184, 0.192402, 0.0098871, 0.0102527]
        ],
        [
          [-0.162211, 9.94329, 0.13723, 0.0124084],
          [-0.253135, 0.00187735, 0.0230286, 0.01264],
          [-0.0695069, -0.0437594, 0.0120636, 0.0163087],
          [-0.0328856, -0.00926032, -0.00173573, 0.00527385]
        ]
      ]

      ERROR_COEFFICIENTS_B = [
        [
          [0.0899116, -19.2349, -4.11711, 0.183362],
          [0.138148, -1.45804, 1.32044, 1.38474],
          [0.230903, -0.450262, 0.219963, 0.414038],
          [0.0590565, -0.101062, 0.0430592, 0.0204699]
        ],
        [
          [0.0164649, 9.89394, 0.0919496, 0.00760802],
          [0.0191603, -0.0322058, 0.0134667, -0.0825018],
          [0.0156192, -0.017535, 0.00326508, -0.228157],
          [-0.0236752, 0.0405821, -0.0173086, 0.176187]
        ]
      ]

      def calculate_curve_approximation_error(a, b, eta1, eta2)
        b_over_a = b / a
        coefficents = b_over_a < 0.25 ? ERROR_COEFFICIENTS_A : ERROR_COEFFICIENTS_B

        c = lambda do |i|
          (0..3).inject(0) do |accumulator, j|
            coef = coefficents[i][j]
            accumulator + ((coef[0] * b_over_a**2 + coef[1] * b_over_a + coef[2]) / (b_over_a * coef[3])) * Math.cos(j * (eta1 + eta2))
          end
        end

        ((0.001 * b_over_a**2 + 4.98 * b_over_a + 0.207) / (b_over_a * 0.0067)) * a * Math.exp(c[0] + c[1] * (eta2 - eta1))
      end
    end
  end
end
