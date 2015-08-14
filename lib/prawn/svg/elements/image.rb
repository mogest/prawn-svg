class Prawn::SVG::Elements::Image < Prawn::SVG::Elements::Base
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

  def parse
    require_attributes 'width', 'height'

    raise SkipElementQuietly if state[:display] == "none"

    @url = attributes['xlink:href'] || attributes['href']
    if @url.nil?
      raise SkipElementError, "image tag must have an xlink:href"
    end

    if !@document.url_loader.valid?(@url)
      raise SkipElementError, "image tag xlink:href attribute must use http, https or data scheme"
    end

    @x = x(attributes['x'] || 0)
    @y = y(attributes['y'] || 0)
    @width = distance(attributes['width'])
    @height = distance(attributes['height'])

    raise SkipElementQuietly if @width.zero? || @height.zero?
    require_positive_value @width, @height
  end

  def apply
    image = begin
      @document.url_loader.load(@url)
    rescue => e
      raise SkipElementError, "Error retrieving URL #{@url}: #{e.message}"
    end

    aspect = Prawn::SVG::Calculators::AspectRatio.new(attributes['preserveAspectRatio'], [@width, @height], image_dimensions(image))

    if aspect.slice?
      add_call "save"
      add_call "rectangle", [@x, @y], @width, @height
      add_call "clip"
    end

    options = {:width => aspect.width, :height => aspect.height, :at => [@x + aspect.x, @y - aspect.y]}

    add_call "image", FakeIO.new(image), options
    add_call "restore" if aspect.slice?
  end

  protected

  def image_dimensions(data)
    handler = if data[0, 3].unpack("C*") == [255, 216, 255]
      Prawn::Images::JPG
    elsif data[0, 8].unpack("C*") == [137, 80, 78, 71, 13, 10, 26, 10]
      Prawn::Images::PNG
    else
      raise SkipElementError, "Unsupported image type supplied to image tag; Prawn only supports JPG and PNG"
    end

    image = handler.new(data)
    [image.width.to_f, image.height.to_f]
  end

  %w(x y distance).each do |method|
    define_method(method) {|*a| @document.send(method, *a)}
  end
end
