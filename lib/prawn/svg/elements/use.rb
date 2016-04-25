class Prawn::SVG::Elements::Use < Prawn::SVG::Elements::Base
  def parse
    require_attributes 'xlink:href'

    href = attributes['xlink:href']

    if href[0..0] != '#'
      raise SkipElementError, "use tag has an href that is not a reference to an id; this is not supported"
    end

    id = href[1..-1]
    @definition_element = @document.elements_by_id[id]

    if @definition_element.nil?
      raise SkipElementError, "no tag with ID '#{id}' was found, referenced by use tag"
    end

    @x = attributes['x']
    @y = attributes['y']
  end

  def apply
    if @x || @y
      add_call_and_enter "translate", x_pixels(@x || 0), -y_pixels(@y || 0)
    end

    add_calls_from_element @definition_element
  end
end
