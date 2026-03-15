class Prawn::SVG::Elements::Image < Prawn::SVG::Elements::Base
  class FakeIO
    def initialize(data)
      @data = data
    end

    def read
      @data
    end

    def rewind; end
  end

  ImageData = Struct.new(:dimensions, :document)

  def parse
    require_attributes 'width', 'height'

    raise SkipElementQuietly if state.computed_properties.display == 'none'

    @url = href_attribute
    raise SkipElementError, 'image tag must have an href or xlink:href' if @url.nil?

    @url, @fragment = extract_fragment(@url)

    x = x(attributes['x'] || 0)
    y = y(attributes['y'] || 0)
    width = x_pixels(attributes['width'])
    height = y_pixels(attributes['height'])
    preserve_aspect_ratio = attributes['preserveAspectRatio']

    raise SkipElementQuietly if width.zero? || height.zero?

    require_positive_value width, height

    @image = begin
      @document.url_loader.load(@url)
    rescue Prawn::SVG::UrlLoader::Error => e
      raise SkipElementError, "Error retrieving URL #{@url}: #{e.message}"
    end

    @image_data = process_image(@image, width, height, preserve_aspect_ratio)

    @aspect = Prawn::SVG::Calculators::AspectRatio.new(preserve_aspect_ratio, [width, height], @image_data.dimensions)

    @clip_x = x
    @clip_y = y
    @clip_width = width
    @clip_height = height

    @width = @aspect.width
    @height = @aspect.height
    @x = x + @aspect.x
    @y = y - @aspect.y
  end

  def apply
    if @aspect.slice?
      add_call 'save'
      add_call 'rectangle', [@clip_x, @clip_y], @clip_width, @clip_height
      add_call 'clip'
    end

    if (document = @image_data.document)
      add_call_and_enter 'translate', @x, @y
      add_call 'svg:render_sub_document', document
    else
      options = { width: @width, height: @height, at: [@x, @y] }

      add_call 'image', FakeIO.new(@image), options
    end

    add_call 'restore' if @aspect.slice?
  end

  def bounding_box
    [@x, @y, @x + @width, @y - @height]
  end

  protected

  def process_image(data, width, height, preserve_aspect_ratio)
    if (handler = find_image_handler(data))
      image = handler.new(data)
      ImageData.new([image.width.to_f, image.height.to_f], nil)

    elsif potentially_svg?(data)
      attribute_overrides = {}
      attribute_overrides['preserveAspectRatio'] = preserve_aspect_ratio if preserve_aspect_ratio

      if @fragment
        view_attrs = resolve_svg_fragment(data, @fragment)
        attribute_overrides.merge!(view_attrs) if view_attrs
      end

      has_web_loader = @document.url_loader.loaders.any? { |l| l.is_a?(Prawn::SVG::Loaders::Web) }
      document = Prawn::SVG::Document.new(
        data, [width, height], { width: width, height: height, enable_web_requests: has_web_loader },
        attribute_overrides: attribute_overrides
      )

      dimensions = [document.sizing.output_width, document.sizing.output_height]
      ImageData.new(dimensions, document)

    else
      raise_invalid_image_type
    end
  rescue Prawn::SVG::Document::InvalidSVGData
    raise_invalid_image_type
  end

  def extract_fragment(url)
    return [url, nil] if url.start_with?('data:')

    if url.include?('#')
      index = url.rindex('#')
      [url[0...index], url[(index + 1)..]]
    else
      [url, nil]
    end
  end

  def resolve_svg_fragment(data, fragment)
    if fragment.start_with?('svgView(') && fragment.end_with?(')')
      parse_svg_view_specification(fragment)
    else
      find_view_element_attributes(data, fragment)
    end
  end

  SVG_VIEW_PARAM_REGEXP = /(\w+)\(([^)]*)\)/.freeze

  def parse_svg_view_specification(fragment)
    spec = fragment[8..-2]
    attrs = {}

    spec.split(';').each do |part|
      next unless (match = part.strip.match(SVG_VIEW_PARAM_REGEXP))

      case match[1]
      when 'viewBox' then attrs['viewBox'] = match[2]
      when 'preserveAspectRatio' then attrs['preserveAspectRatio'] = match[2]
      end
    end

    attrs.empty? ? nil : attrs
  end

  def find_view_element_attributes(data, fragment)
    root = REXML::Document.new(data).root
    return unless root

    element = REXML::XPath.match(root, %(//*[@id="#{fragment.gsub('"', '\\"')}"])).first
    return unless element&.name == 'view'

    attrs = {}
    attrs['viewBox'] = element.attributes['viewBox'] if element.attributes['viewBox']
    attrs['preserveAspectRatio'] = element.attributes['preserveAspectRatio'] if element.attributes['preserveAspectRatio']
    attrs.empty? ? nil : attrs
  rescue REXML::ParseException
    nil
  end

  def find_image_handler(data)
    Prawn.image_handler.find(data)
  rescue StandardError
    nil
  end

  def potentially_svg?(data)
    data.include?('<svg')
  end

  def raise_invalid_image_type
    raise SkipElementError, 'Unsupported image type supplied to image tag'
  end
end
