module Prawn::SVG::Calculators
  class PathLength
    Segment = Struct.new(:start_point, :end_point, :type, :control_points, :segment_length, :cumulative_length, :lookup_table)

    SUBDIVISION_TOLERANCE = 0.01
    LOOKUP_TABLE_STEPS = 64

    attr_reader :total_length

    def initialize(commands)
      @segments = []
      @total_length = 0.0

      current_point = nil
      subpath_start = nil

      commands.each do |command|
        case command
        when Prawn::SVG::Pathable::Move
          current_point = command.destination
          subpath_start = current_point

        when Prawn::SVG::Pathable::Close
          if current_point && subpath_start && current_point != subpath_start
            add_line_segment(current_point, subpath_start)
            current_point = subpath_start
          end

        when Prawn::SVG::Pathable::Line
          if current_point
            add_line_segment(current_point, command.destination)
            current_point = command.destination
          end

        when Prawn::SVG::Pathable::Curve
          if current_point
            add_curve_segment(current_point, command.point1, command.point2, command.destination)
            current_point = command.destination
          end
        end
      end
    end

    def point_at(distance)
      return nil if distance.negative? || distance > @total_length || @segments.empty?

      @segments.each do |segment|
        start_distance = segment.cumulative_length - segment.segment_length

        next unless distance <= segment.cumulative_length

        local_distance = distance - start_distance

        case segment.type
        when :line
          t = segment.segment_length.positive? ? local_distance / segment.segment_length : 0.0
          x = segment.start_point[0] + (t * (segment.end_point[0] - segment.start_point[0]))
          y = segment.start_point[1] + (t * (segment.end_point[1] - segment.start_point[1]))
          dx = segment.end_point[0] - segment.start_point[0]
          dy = segment.end_point[1] - segment.start_point[1]
          angle = Math.atan2(dy, dx) * 180.0 / Math::PI
          return [x, y, angle]

        when :curve
          t = find_t_for_distance(segment, local_distance)
          p0, p1, p2, p3 = segment.start_point, *segment.control_points, segment.end_point
          x, y = evaluate_cubic(p0, p1, p2, p3, t)
          dx, dy = evaluate_cubic_derivative(p0, p1, p2, p3, t)
          angle = Math.atan2(dy, dx) * 180.0 / Math::PI
          return [x, y, angle]
        end
      end

      # Exactly at the end
      segment = @segments.last
      [segment.end_point[0], segment.end_point[1], end_angle(segment)]
    end

    private

    def add_line_segment(start_point, end_point)
      length = Math.sqrt(((end_point[0] - start_point[0])**2) + ((end_point[1] - start_point[1])**2))
      @total_length += length
      @segments << Segment.new(start_point, end_point, :line, nil, length, @total_length, nil)
    end

    def add_curve_segment(start_point, control1, control2, end_point)
      lookup_table = build_lookup_table(start_point, control1, control2, end_point)
      length = lookup_table.last
      @total_length += length
      @segments << Segment.new(start_point, end_point, :curve, [control1, control2], length, @total_length, lookup_table)
    end

    def build_lookup_table(p0, p1, p2, p3)
      table = [0.0]
      prev_point = p0
      cumulative = 0.0

      1.upto(LOOKUP_TABLE_STEPS) do |i|
        t = i.to_f / LOOKUP_TABLE_STEPS
        point = evaluate_cubic(p0, p1, p2, p3, t)
        cumulative += Math.sqrt(((point[0] - prev_point[0])**2) + ((point[1] - prev_point[1])**2))
        table << cumulative
        prev_point = point
      end

      table
    end

    def find_t_for_distance(segment, target_distance)
      table = segment.lookup_table
      return 0.0 if target_distance <= 0
      return 1.0 if target_distance >= segment.segment_length

      # Binary search in the lookup table
      low = 0
      high = LOOKUP_TABLE_STEPS

      while low < high - 1
        mid = (low + high) / 2
        if table[mid] < target_distance
          low = mid
        else
          high = mid
        end
      end

      # Linear interpolation between low and high
      d_low = table[low]
      d_high = table[high]
      fraction = d_high > d_low ? (target_distance - d_low) / (d_high - d_low) : 0.0
      (low + fraction) / LOOKUP_TABLE_STEPS
    end

    def evaluate_cubic(p0, p1, p2, p3, t)
      mt = 1.0 - t
      mt2 = mt * mt
      mt3 = mt2 * mt
      t2 = t * t
      t3 = t2 * t

      x = (mt3 * p0[0]) + (3 * mt2 * t * p1[0]) + (3 * mt * t2 * p2[0]) + (t3 * p3[0])
      y = (mt3 * p0[1]) + (3 * mt2 * t * p1[1]) + (3 * mt * t2 * p2[1]) + (t3 * p3[1])
      [x, y]
    end

    def evaluate_cubic_derivative(p0, p1, p2, p3, t)
      mt = 1.0 - t

      dx = (3 * mt * mt * (p1[0] - p0[0])) + (6 * mt * t * (p2[0] - p1[0])) + (3 * t * t * (p3[0] - p2[0]))
      dy = (3 * mt * mt * (p1[1] - p0[1])) + (6 * mt * t * (p2[1] - p1[1])) + (3 * t * t * (p3[1] - p2[1]))
      [dx, dy]
    end

    def end_angle(segment)
      case segment.type
      when :line
        dx = segment.end_point[0] - segment.start_point[0]
        dy = segment.end_point[1] - segment.start_point[1]
        Math.atan2(dy, dx) * 180.0 / Math::PI
      when :curve
        p0, p1, p2, p3 = segment.start_point, *segment.control_points, segment.end_point
        dx, dy = evaluate_cubic_derivative(p0, p1, p2, p3, 1.0)
        Math.atan2(dy, dx) * 180.0 / Math::PI
      end
    end
  end
end
