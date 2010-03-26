class Prawn::Svg
  attr_reader :data, :prawn, :options

  def initialize(data, prawn, options)
    @data = data
    @prawn = prawn
    @options = options

    @parser = Parser.new(data, options)
  end

  def draw
    prawn.bounding_box(@options[:at], :width => @parser.width, :height => @parser.height) do
      prawn.save_graphics_state do
        proc_creator(prawn, @parser.parse).call
      end
    end
  end
  
  
  
  protected  
  def proc_creator(prawn, calls)
    Proc.new {issue_prawn_command(prawn, calls)}
  end
  
  def issue_prawn_command(prawn, calls)
    calls.each do |call, arguments, children|
      if children.empty?
        rewrite_call_arguments(prawn, call, arguments)
        prawn.send(call, *arguments)
      else
        prawn.send(call, *arguments, &proc_creator(prawn, children))
      end
    end
  end
  
  def rewrite_call_arguments(prawn, call, arguments)
    if call == 'text_box'
      if (anchor = arguments.last.delete(:text_anchor)) && %w(middle end).include?(anchor)
        width = prawn.width_of(*arguments)
        width /= 2 if anchor == 'middle'
        arguments.last[:at][0] -= width
      end
      
      arguments.last[:at][1] += prawn.height_of(*arguments) / 3 * 2
    end
  end
end
