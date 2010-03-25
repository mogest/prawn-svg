#
# Renders a SVG document with Prawn
#
# Requires prawn and rexml
#
# Copyright 2010 Roger Nesbitt (http://seriousorange.com/)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

require 'rexml/document'

class Prawn::Svg
  attr_reader :data, :prawn, :options
  attr_accessor :scale

  def initialize(data, prawn, options)
    @data = data
    @prawn = prawn
    @options = options
  end

  def draw
    root = parse_document
    @actual_width = root.attributes['width'].to_f
    @actual_height = root.attributes['height'].to_f

    calculate_dimensions

    prawn.bounding_box(@options[:at], :width => @width, :height => @height) do    
      proc_creator(prawn, generate_call_tree(root)).call
    end
  end
  
  def calculate_dimensions    
    if @options[:width]
      @width = @options[:width]      
      @scale = @options[:width] / @actual_width.to_f
    elsif @options[:height]
      @height = @options[:height]
      @scale = @options[:height] / @actual_height.to_f
    else
      @scale = 1
    end
    
    @width ||= @actual_width * @scale
    @height ||= @actual_height * @scale
  end        
  
  def proc_creator(prawn, calls)
    Proc.new do
      calls.each do |call, arguments, children|
        if children.empty?
          rewrite_call_arguments(prawn, call, arguments)
          prawn.send(call, *arguments)
        else
          prawn.send(call, *arguments, &proc_creator(prawn, children))
        end
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

  def parse_document
    REXML::Document.new(@data).root
  end
  
  def generate_call_tree(element)
    [].tap {|calls| parse_element(element, calls)}
  end
  
  private
  def parse_element(element, calls)
    attrs = element.attributes

    if transform = attrs['transform']
      parse_css_method_calls(transform).each do |name, arguments|
        case name
        when 'translate'
          calls << [name, [distance(arguments.first), -distance(arguments.second)], []]
          calls = calls.last.last
        when 'rotate'
          rotation = arguments.first.to_f
          if rotation != 0
            calls << [name, [rotation], []]
            calls = calls.last.last
          end
        else
          raise "unknown transformation '#{name}'"
        end
      end
    end

    calls, style_attrs, draw_type = apply_styles(attrs, calls)
  
    case element.name
    when 'defs'
      # skip over the defs section
      
    when 'g', 'svg'
      element.elements.each do |child|
        parse_element(child, calls)
      end

    when 'text'
      opts = {:at => [x(attrs['x']), y(attrs['y'])]}
      if size = style_attrs['font-size']
        opts[:size] = size.to_f * @scale
      end
            
      # This is not a prawn option but we can't work out how to render it here - it's handled by #rewrite_call
      if anchor = style_attrs['text-anchor']
        opts[:text_anchor] = anchor        
      end
      
      calls << ['text_box', [element.text, opts], []]

    when 'line'
      calls << ['stroke_line', [x(attrs['x1']), y(attrs['y1']), x(attrs['x2']), y(attrs['y2'])], []]

    when 'polyline'
      attrs['points'].split(/\s+/).each_cons(2) do |point_a, point_b|
        x1, y1 = point_a.split(",")
        x2, y2 = point_b.split(",")
        calls << ['stroke_line', [x(x1), y(y1), x(x2), y(y2)], []]
      end
      
    when 'rect'      
      raise "one of fill or stroke must be specified" if draw_type.blank?
      calls << ["#{draw_type}_rectangle", [[x(attrs['x']), y(attrs['y'])], distance(attrs['width']), distance(attrs['height'])], []]
      
    else raise "unknown tag #{element.name}"
    end
  end
  
  def parse_css_declarations(declarations)
    # copied from css_parser
    declarations.gsub!(/(^[\s]*)|([\s]*$)/, '')

    declarations.split(/[\;$]+/m).each_with_object({}) do |decs, o|
      if matches = decs.match(/\s*(.[^:]*)\s*\:\s*(.[^;]*)\s*(;|\Z)/i)
        property, value, end_of_declaration = matches.captures
        o[property] = value
      end
    end
  end
  
  def apply_styles(attrs, calls)
    decs = attrs["style"] ? parse_css_declarations(attrs["style"]) : {}
    attrs.each {|n,v| decs[n] = v unless decs[n]}
    
    draw_types = []
    if decs['fill-opacity']
      calls << ['transparent', [decs['fill-opacity'].to_f, 1], []] 
      calls = calls.last.last
    end

    if decs['fill'] && decs['fill'] != "none"
      if color = color_to_hex(decs['fill'])
        calls << ['fill_color', [color], []]
      end
      draw_types << 'fill'
    end
    
    if decs['stroke'] && decs['stroke'] != "none"
      if color = color_to_hex(decs['stroke'])
        calls << ['stroke_color', [color], []]
      end
      draw_types << 'stroke'
    end
    
    calls << ['line_width', [decs['stroke-width'].to_f], []] if decs['stroke-width']          
        
    [calls, decs, draw_types.join("_and_")]
  end
  
  def parse_css_method_calls(string)
    string.scan(/\s*(\w+)\(([^)]+)\)\s*/).collect do |call|
      name, argument_string = call
      arguments = argument_string.split(",").collect(&:strip)
      [name, arguments]
    end    
  end
  
  def color_to_hex(color)
    html_colors = {"black" => "000000", "white" => "ffffff"} # TODO - get the official list from somewhere
    
    color = color.split(' ').last # we always take the fallback option
    
    if color.first == "#"
      color[1..-1]
    elsif hex = html_colors[color.downcase]
      hex
    end    
  end
  
  def x(value)
    value.to_f * scale
  end
  
  def y(value)
    (@actual_height - (value.to_f)) * scale
  end
  
  def distance(value)
    value.to_f * scale
  end
end
