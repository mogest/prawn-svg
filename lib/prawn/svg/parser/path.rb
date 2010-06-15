module Prawn
  module Svg
    class Parser::Path
      # Raised if the SVG path cannot be parsed.
      InvalidError = Class.new(StandardError)

      #
      # Parses an SVG path and returns a Prawn-compatible call tree.
      #
      def parse(data)
        cmd = values = nil
        value = ""
        @subpath_initial_point = @last_point = nil
        @previous_control_point = @previous_quadratic_control_point = nil
        @calls = []

        data.each_char do |c|
          if c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z'
            values << value.to_f if value != ""
            run_path_command(cmd, values) if cmd
            cmd = c
            values = []
            value = ""
          elsif c >= '0' && c <= '9' || c == '.' || (c == "-" && value == "")
            unless cmd
              raise InvalidError, "Numerical value specified before character command in SVG path data"
            end
            value << c
          elsif c == ' ' || c == "\t" || c == "\r" || c == "\n" || c == ","
            if value != ""
              values << value.to_f
              value = ""
            end
          elsif c == '-'
            values << value.to_f
            value = c
          else
            raise InvalidError, "Invalid character '#{c}' in SVG path data"
          end
        end
    
        values << value.to_f if value != ""
        run_path_command(cmd, values) if cmd
    
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
      
          return run_path_command('L', values) if values.any?
      
        when 'Z' # closepath
          if @subpath_initial_point
            @calls << ["line_to", @subpath_initial_point]
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
    end
  end  
end
