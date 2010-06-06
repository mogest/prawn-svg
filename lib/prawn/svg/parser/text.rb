class Prawn::Svg::Parser::Text
  BUILT_IN_FONTS = ["Courier", "Helvetica", "Times-Roman", "Symbol", "ZapfDingbats"]

  GENERIC_CSS_FONT_MAPPING = {
    "serif"      => "Times-Roman",
    "sans-serif" => "Helvetica",
    "cursive"    => "Times-Roman",
    "fantasy"    => "Times-Roman",
    "monospace"  => "Courier"}
    
  def parse(element)    
    attrs = element.attributes
    
    if (font_family = attrs["font-family"]) && font_family.strip != ""
      if pdf_font = map_font_family_to_pdf_font(font_family)
        element.add_call_and_enter 'font', pdf_font
      else
        element.warnings << "#{font_family} is not a known font."
      end
    end

    opts = {:at => [element.document.x(attrs['x']), element.document.y(attrs['y'])]}
    if size = attrs['font-size']
      opts[:size] = size.to_f * element.document.scale
    end
      
    # This is not a prawn option but we can't work out how to render it here -
    # it's handled by Svg#rewrite_call_arguments
    if anchor = attrs['text-anchor']
      opts[:text_anchor] = anchor        
    end

    text = element.element.text.strip.gsub(/\s+/, " ")
    element.add_call 'draw_text', text, opts
  end
  
  
  private
  def installed_fonts
    @installed_fonts ||= Prawn::Svg::Interface.font_path.uniq.collect {|path| Dir["#{path}/*"]}.flatten
  end

  def map_font_family_to_pdf_font(font_family)
    font_family.split(",").detect do |font|
      font = font.gsub(/['"]/, '').gsub(/\s{2,}/, ' ').strip.downcase

      built_in_font = BUILT_IN_FONTS.detect {|f| f.downcase == font}
      break built_in_font if built_in_font

      generic_font = GENERIC_CSS_FONT_MAPPING[font]
      break generic_font if generic_font

      installed_font = installed_fonts.detect do |file|
        (matches = File.basename(file).match(/(.+)\./)) && matches[1].downcase == font
      end
      break installed_font if installed_font
    end
  end
end
