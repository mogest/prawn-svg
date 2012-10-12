require 'open-uri'

class Prawn::Svg::Parser::Image
  Error = Class.new(StandardError)

  class FakeIO
    def initialize(data)
      @data = data
    end
    def read
      @data
    end
  end

  def initialize(document)
    @document = document
  end

  def parse(element)
    attrs = element.attributes
    url = attrs['xlink:href'] || attrs['href']
    if url.nil?
      raise Error, "image tag must have an xlink:href"
    end
    if url.match(%r{\Ahttps?://}).nil?
      raise Error, "image tag xlink:href attribute must use http or https scheme"
    end

    image = begin
      open(url).read
    rescue => e
      raise Error, "Error retrieving URL #{url}: #{e.message}"
    end

    x = x(attrs['x'] || 0)
    y = y(attrs['y'] || 0)
    width = distance(attrs['width'])
    height = distance(attrs['height'])
    options = {}

    return if width.zero? || height.zero?
    raise Error, "width and height must be 0 or higher" if width < 0 || height < 0

    par = (attrs['preserveAspectRatio'] || "xMidYMid meet").strip.split(/\s+/)
    par.shift if par.first == "defer"

    case par.first
    when 'xMidYMid'
      ratio = image_ratio(image)
      if width < height
        options[:width] = width
        y -= height/2 - width/ratio/2
      elsif width > height
        options[:height] = height
        x += width/2 - height*ratio/2
      else
        options[:fit] = [width, height]
        if ratio >= 1
          y -= height/2 - width/ratio/2
        else
          x += width/2 - height*ratio/2
        end
      end
    when 'none'
      options[:width] = width
      options[:height] = height
    else
      raise Error, "image tag only support preserveAspectRatio with xMidYMid or none; ignoring"
    end

    options[:at] = [x, y]

    element.add_call "image", FakeIO.new(image), options
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
    [image.width, image.height]
  end

  def image_ratio(data)
    w, h = image_dimensions(data)
    w.to_f / h.to_f
  end

  %w(x y distance).each do |method|
    define_method(method) {|*a| @document.send(method, *a)}
  end
end
