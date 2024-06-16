class Prawn::SVG::Elements::Use < Prawn::SVG::Elements::Base
  attr_reader :referenced_element_class, :referenced_element_source

  def parse
    href = href_attribute
    raise SkipElementError, 'use tag must have an href or xlink:href' if href.nil?

    if href[0..0] != '#'
      raise SkipElementError, 'use tag has an href that is not a reference to an id; this is not supported'
    end

    id = href[1..]
    referenced_element = @document.elements_by_id[id]

    if referenced_element
      @referenced_element_class = referenced_element.class
      @referenced_element_source = referenced_element.source
    else
      # Perhaps the element is defined further down in the document.  This is not recommended but still valid SVG,
      # so we'll support it with an exception case that's not particularly performant.
      raw_element = REXML::XPath.match(@document.root, %(//*[@id="#{id.gsub('"', '\"')}"])).first

      if raw_element
        @referenced_element_class = Prawn::SVG::Elements::TAG_CLASS_MAPPING[raw_element.name.to_sym]
        @referenced_element_source = raw_element
      end
    end

    raise SkipElementError, "no tag with ID '#{id}' was found, referenced by use tag" if referenced_element_class.nil?

    @referenced_element_class = Prawn::SVG::Elements::Viewport if referenced_element_source.name == 'symbol'

    state.inside_use = true

    @x = attributes['x']
    @y = attributes['y']
    @width = attributes['width']
    @height = attributes['height']
  end

  def container?
    true
  end

  def apply
    add_call_and_enter 'translate', x_pixels(@x || 0), -y_pixels(@y || 0) if @x || @y
  end

  def process_child_elements
    add_call 'save'

    source = clone_element_source(referenced_element_source)

    if referenced_element_class == Prawn::SVG::Elements::Viewport
      source.attributes['width'] = @width || '100%'
      source.attributes['height'] = @height || '100%'
    end

    child = referenced_element_class.new(document, source, calls, state.dup)
    child.process

    add_call 'restore'
  end
end
