require 'open-uri'
require 'base64'

class Prawn::Svg::Parser::Image
  Error = Class.new(StandardError)

  DATAURL_REGEXP = /(data:image\/(png|jpg);base64(;[a-z0-9]+)*,)/
  URL_REGEXP = /^https?:\/\/|#{DATAURL_REGEXP}/

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
    attrs = element.attributes
    url = attrs['xlink:href'] || attrs['href']
    if url.nil?
      raise Error, "image tag must have an xlink:href"
    end

    if !url.match(URL_REGEXP)
      raise Error, "image tag xlink:href attribute must use http, https or data scheme"
    end

    image = begin
      retrieve_data_from_url(url)
    rescue => e
      raise Error, "Error retrieving URL #{url}: #{e.message}"
    end

    x = x(attrs['x'] || 0)
    y = y(attrs['y'] || 0)
    width = distance(attrs['width'])
    height = distance(attrs['height'])

    return if width.zero? || height.zero?
    raise Error, "width and height must be 0 or higher" if width < 0 || height < 0

    par = (attrs['preserveAspectRatio'] || "xMidYMid meet").strip.split(/\s+/)
    par.shift if par.first == "defer"
    align, meet_or_slice = par
    slice = meet_or_slice == "slice"

    if slice
      element.add_call "save"
      element.add_call "rectangle", [x, y], width, height
      element.add_call "clip"
    end

    options = {}
    case align
    when /\Ax(Min|Mid|Max)Y(Min|Mid|Max)\z/
      ratio = image_ratio(image)

      options[:fit] = [width, height] unless slice

      if (width/height > ratio) == slice
        options[:width] = width if slice
        y -= case $2
             when "Min" then 0
             when "Mid" then (height - width/ratio)/2
             when "Max" then height - width/ratio
             end
      else
        options[:height] = height if slice
        x += case $1
             when "Min" then 0
             when "Mid" then (width - height*ratio)/2
             when "Max" then width - height*ratio
             end
      end
    when 'none'
      options[:width] = width
      options[:height] = height
    else
      raise Error, "unknown preserveAspectRatio align keyword; ignoring image"
    end

    options[:at] = [x, y]

    element.add_call "image", FakeIO.new(image), options
    element.add_call "restore" if slice
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

  def retrieve_data_from_url(url)
    @url_cache[url] || begin
      if m = url.match(DATAURL_REGEXP)
        data = Base64.decode64(url[m[0].length .. -1])
      else
        data = open(url).read
      end
      @url_cache[url] = data if @document.cache_images
      data
    end
  end

  %w(x y distance).each do |method|
    define_method(method) {|*a| @document.send(method, *a)}
  end
end
