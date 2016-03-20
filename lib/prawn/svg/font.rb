class Prawn::SVG::Font
  GENERIC_CSS_FONT_MAPPING = {
    "serif"      => "Times-Roman",
    "sans-serif" => "Helvetica",
    "cursive"    => "Times-Roman",
    "fantasy"    => "Times-Roman",
    "monospace"  => "Courier"}

  attr_reader :name, :weight, :style

  def self.load(family, weight = nil, style = nil)
    family.split(",").detect do |name|
      name = name.gsub(/['"]/, '').gsub(/\s{2,}/, ' ').strip.downcase

      # If it's a standard CSS font name, map it to one of the standard PDF fonts.
      name = GENERIC_CSS_FONT_MAPPING[name] || name

      font = new(name, weight, style)
      break font if font.installed?
    end
  end

  def self.weight_for_css_font_weight(weight)
    case weight
    when '100', '200', '300' then :light
    when '400', '500'        then :normal
    when '600'               then :semibold
    when '700', 'bold'       then :bold
    when '800'               then :extrabold
    when '900'               then :black
    end
  end

  # This method is passed prawn's font_families hash.  It'll be pre-populated with the fonts that prawn natively
  # supports.  We'll add fonts we find in the font path to this hash.
  def self.load_external_fonts(fonts)
    Prawn::SVG::Interface.font_path.uniq.collect {|path| Dir["#{path}/**/*"]}.flatten.each do |filename|
      ttf = Prawn::SVG::TTF.new(filename)
      if ttf.family
        subfamily = (ttf.subfamily || "normal").gsub(/\s+/, "_").downcase.to_sym
        subfamily = :normal if subfamily == :regular
        (fonts[ttf.family] ||= {})[subfamily] ||= filename
      end
    end

    @font_case_mapping = {}
    fonts.each {|key, _| @font_case_mapping[key.downcase] = key}

    @installed_fonts = fonts
  end

  def self.installed_fonts
    @installed_fonts
  end

  def self.correctly_cased_font_name(name)
    @font_case_mapping[name.downcase]
  end


  def initialize(name, weight, style)
    @name = self.class.correctly_cased_font_name(name) || name
    @weight = weight
    @style = style
  end

  def installed?
    subfamilies = self.class.installed_fonts[name]
    !subfamilies.nil? && subfamilies.key?(subfamily)
  end

  # Construct a subfamily name, ensuring that the subfamily is a valid one for the font.
  def subfamily
    if subfamilies = self.class.installed_fonts[name]
      if subfamilies.key?(subfamily_name)
        subfamily_name
      elsif subfamilies.key?(:normal)
        :normal
      else
        subfamilies.keys.first
      end
    end
  end


  private
  # Construct a subfamily name from the weight and style information.
  # Note that this name might not actually exist in the font.
  def subfamily_name
    sfn = if weight == :normal && style
      style
    elsif weight || style
      "#{weight} #{style}"
    else
      "normal"
    end

    sfn.strip.gsub(/\s+/, "_").downcase.to_sym
  end
end
