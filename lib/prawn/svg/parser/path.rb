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
          # unsupported
        end

        @previous_control_point = nil unless %w(C S).include?(upcase_command)
        @previous_quadratic_control_point = nil unless %w(Q T).include?(upcase_command)
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
    end
  end
end
