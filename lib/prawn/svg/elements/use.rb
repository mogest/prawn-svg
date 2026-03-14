class Prawn::SVG::Elements::Use < Prawn::SVG::Elements::Base
  attr_reader :referenced_element_class, :referenced_element_source

  def parse
    href = href_attribute
    raise SkipElementError, 'use tag must have an href or xlink:href' if href.nil?

    if href.start_with?('#')
      resolve_local_reference(href[1..])
    else
      resolve_external_reference(href)
    end

    raise SkipElementError, "use tag references '#{href}' which could not be resolved" if referenced_element_class.nil?

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

  private

  def resolve_local_reference(id)
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
  end

  def resolve_external_reference(href)
    url, fragment = split_href(href)
    raise SkipElementError, 'use tag with external href must include a fragment identifier' unless fragment

    external_root, external_element_styles = load_external_svg(url)

    raw_element = REXML::XPath.match(external_root, %(//*[@id="#{fragment.gsub('"', '\"')}"])).first
    return unless raw_element

    @referenced_element_class = Prawn::SVG::Elements::TAG_CLASS_MAPPING[raw_element.name.to_sym]
    return unless @referenced_element_class

    @referenced_element_source = raw_element

    import_external_styles(raw_element, external_element_styles)
    import_external_defs(external_root, external_element_styles)
  end

  def split_href(href)
    if href.include?('#')
      fragment_index = href.rindex('#')
      [href[0...fragment_index], href[(fragment_index + 1)..]]
    else
      [href, nil]
    end
  end

  def load_external_svg(url)
    @document.external_svg_cache[url] ||= begin
      data = @document.url_loader.load(url)

      root = begin
        REXML::Document.new(data).root
      rescue REXML::ParseException
        raise SkipElementError, "use tag references external SVG at '#{url}' which could not be parsed"
      end

      raise SkipElementError, "use tag references external URL '#{url}' which does not contain SVG" unless root

      css_parser = CssParser::Parser.new
      stylesheets = Prawn::SVG::CSS::Stylesheets.new(css_parser, root)
      element_styles = stylesheets.load

      [root, element_styles]
    end
  rescue Prawn::SVG::UrlLoader::Error => e
    raise SkipElementError, "use tag could not load external SVG from '#{url}': #{e.message}"
  end

  def import_external_styles(element, external_element_styles)
    copy_styles_recursive(element, external_element_styles)
  end

  def import_external_defs(external_root, external_element_styles)
    REXML::XPath.match(external_root, '//defs').each do |defs_element|
      defs_element.elements.each do |child|
        id = child.attributes['id']
        next unless id && !id.empty?

        copy_styles_recursive(child, external_element_styles)
      end
    end
  end

  def copy_styles_recursive(element, external_element_styles)
    styles = external_element_styles[element]
    @document.element_styles[element] = styles if styles

    element.elements.each do |child|
      copy_styles_recursive(child, external_element_styles)
    end
  end
end
