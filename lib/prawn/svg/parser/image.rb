class Prawn::Svg::Parser::Image
  Error = Class.new(StandardError)

  class FakeIO
    def initialize(data)
      @data = data
    end
    def read
      @data
    end
    def rewind
    end
  end

  def initialize(document)
    @document = document
    @url_cache = {}
  end

  def parse(element)
    return if element.state[:display] == "none"

    attrs = element.attributes
    url = attrs['xlink:href'] || attrs['href']
    if url.nil?
      raise Error, "image tag must have an xlink:href"
    end

    if !@document.url_loader.valid?(url)
      raise Error, "image tag xlink:href attribute must use http, https or data scheme"
    end

    image = begin
      @document.url_loader.load(url)
    rescue => e
      raise Error, "Error retrieving URL #{url}: #{e.message}"
    end

    x = x(attrs['x'] || 0)
    y = y(attrs['y'] || 0)
    width = distance(attrs['width'])
    height = distance(attrs['height'])

    return if width.zero? || height.zero?
    raise Error, "width and height must be 0 or higher" if width < 0 || height < 0

    aspect = Prawn::Svg::Calculators::AspectRatio.new(attrs['preserveAspectRatio'], [width, height], image_dimensions(image))

    if aspect.slice?
      element.add_call "save"
      element.add_call "rectangle", [x, y], width, height
      element.add_call "clip"
    end

    options = {:width => aspect.width, :height => aspect.height, :at => [x + aspect.x, y - aspect.y]}

    element.add_call "image", FakeIO.new(image), options
    element.add_call "restore" if aspect.slice?
  rescue Error => e
    @document.warnings << e.message
  end


  protected
  def image_dimensions(data)
    handler = if data[0, 3].unpack("C*") == [255, 216, 255]
      Prawn::Images::JPG
    elsif data[0, 8].unpack("C*") == [137, 80, 78, 71, 13, 10, 26, 10]
      Prawn::Images::PNG
    else
      raise Error, "Unsupported image type supplied to image tag; Prawn only supports JPG and PNG"
    end

    image = handler.new(data)
    [image.width.to_f, image.height.to_f]
  end

  %w(x y distance).each do |method|
    define_method(method) {|*a| @document.send(method, *a)}
  end
end
