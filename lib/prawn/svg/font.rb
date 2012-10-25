class Prawn::Svg::Font
  BUILT_IN_FONTS = ["Courier", "Helvetica", "Times-Roman", "Symbol", "ZapfDingbats"]

  GENERIC_CSS_FONT_MAPPING = {
    "serif"      => "Times-Roman",
    "sans-serif" => "Helvetica",
    "cursive"    => "Times-Roman",
    "fantasy"    => "Times-Roman",
    "monospace"  => "Courier"}
    
  def self.map_font_family_to_pdf_font(font_family, font_weight = nil, font_style = nil)
    font_family.split(",").detect do |font|
      font = font.gsub(/['"]/, '').gsub(/\s{2,}/, ' ').strip.downcase

      built_in_font = BUILT_IN_FONTS.detect {|f| f.downcase == font}
      break built_in_font if built_in_font

      generic_font = GENERIC_CSS_FONT_MAPPING[font]
      break generic_font if generic_font

      break font.downcase if font_installed?(font, font_weight, font_style)
    end
  end
  
  def self.font_path(font_family, font_weight = nil, font_style = nil)
    if installed_fonts.key? font_family
      installed_fonts[font_family][font_subfamily(font_family,font_weight, font_style)]
    end
  end
  
  def self.font_installed?(font_family, font_weight = nil, font_style = nil)
    !font_path(font_family.downcase, font_weight, font_style).nil?
  end

  def self.installed_fonts
    return @installed_fonts if @installed_fonts
    
    fonts = {}
    Prawn::Svg::Interface.font_path.uniq.collect {|path| Dir["#{path}/*"]}.flatten.each do |filename|
      information = font_information(filename) rescue nil
      if information && font_name = (information[16] || information[1])
        subfamily = (information[17] || information[2]).gsub(/\s+/, "_").downcase.to_sym
        subfamily = :normal if subfamily == :regular
        (fonts[font_name.downcase] ||= {})[subfamily] = filename
      end
    end
    @installed_fonts = fonts
  end

  def self.font_subfamily(font_family,font_weight = nil,font_style = nil)
    subfamily = (if font_weight == :normal and font_style
                  "#{font_style}"
                elsif font_weight || font_style
                  "#{font_weight} #{font_style}"
                else
                  "normal"
                end).strip().gsub(/\s+/, "_").downcase.to_sym

    if installed_styles = installed_fonts[font_family.downcase]
      if installed_styles.key? subfamily
        subfamily
      elsif installed_styles.key? :normal
        :normal
      else
        installed_styles.values.first
      end
    end
  end
    
  def self.font_information(filename)
    File.open(filename, "r") do |f|
      x = f.read(12)
      table_count = x[4].ord * 256 + x[5].ord
      tables = f.read(table_count * 16)

      offset, length = table_count.times do |index|
        start = index * 16
        if tables[start..start+3] == 'name'
          break tables[start+8..start+15].unpack("NN")
        end
      end
      
      return unless length
      f.seek(offset)
      data = f.read(length)
      
      format, name_count, string_offset = data[0..5].unpack("nnn")

      names = {}
      name_count.times do |index|
        start = 6 + index * 12
        platform_id, platform_specific_id, language_id, name_id, length, offset = data[start..start+11].unpack("nnnnnn")        
        next unless language_id == 0 # English
        next unless name_id == 1 || name_id == 2 || name_id == 16 || name_id == 17
        
        offset += string_offset
        field = data[offset..offset+length-1]        
        names[name_id] = if platform_id == 0
          begin
            if field.respond_to?(:encode)
              field.encode(Encoding::UTF16)
            else
              require "iconv"
              Iconv.iconv('UTF-8', 'UTF-16', field)
            end
          rescue
            field
          end
        else
          field
        end
      end
      names
    end
  end
end
