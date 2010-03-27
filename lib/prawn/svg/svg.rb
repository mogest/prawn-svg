#
# Prawn::Svg makes a Prawn::Svg::Parser instance, uses that object to parse the supplied
# SVG into Prawn-compatible method calls, and then calls the Prawn methods.
#
class Prawn::Svg
  attr_reader :data, :prawn, :options
  
  # An +Array+ of warnings that occurred while parsing the SVG data.  If this array is non-empty,
  # it's likely that the SVG failed to render correctly.
  attr_reader :parser_warnings

  #
  # Creates a Prawn::Svg object.
  #
  # +data+ is the SVG data to convert.  +prawn+ is your Prawn::Document object.
  #
  # +options+ must contain the key :at, which takes a tuple of x and y co-ordinates.
  #
  # +options+ can optionally contain the key :width or :height.  If both are 
  # specified, only :width will be used.
  #
  def initialize(data, prawn, options)
    @data = data
    @prawn = prawn
    @options = options
    
    @options[:at] or raise "options[:at] must be specified"

    @parser = Parser.new(data, options)
    @parser_warnings = @parser.warnings
  end

  #
  # Draws the SVG to the Prawn::Document object.
  #
  def draw
    prawn.bounding_box(@options[:at], :width => @parser.width, :height => @parser.height) do
      prawn.save_graphics_state do
        proc_creator(prawn, @parser.parse).call
      end
    end
  end

  
  private  
  def proc_creator(prawn, calls)
    Proc.new {issue_prawn_command(prawn, calls)}
  end
  
  def issue_prawn_command(prawn, calls)
    calls.each do |call, arguments, children|
      if rewrite_call_arguments(prawn, call, arguments) == false
        issue_prawn_command(prawn, children) if children.any?
      else
        if children.empty?
          prawn.send(call, *arguments)
        else
          prawn.send(call, *arguments, &proc_creator(prawn, children))
        end
      end
    end
  end
  
  def rewrite_call_arguments(prawn, call, arguments)
    case call
    when 'text_box'
      if (anchor = arguments.last.delete(:text_anchor)) && %w(middle end).include?(anchor)
        width = prawn.width_of(*arguments)
        width /= 2 if anchor == 'middle'
        arguments.last[:at][0] -= width
      end
      
      arguments.last[:at][1] += prawn.height_of(*arguments) / 3 * 2
      
    when 'font'
      unless prawn.font_families.member?(arguments.first)      
        @parser_warnings << "#{arguments.first} is not a known font."
        false
      end
    end
  end
end
