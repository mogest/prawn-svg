module Prawn::SVG::Attributes::Font
  def parse_font_attributes_and_call
    if size = attributes['font-size']
      @state[:font_size] = size.to_f
    end
    if weight = attributes['font-weight']
      font_updated = true
      @state[:font_weight] = Prawn::SVG::Font.weight_for_css_font_weight(weight)
    end
    if style = attributes['font-style']
      font_updated = true
      @state[:font_style] = style == 'italic' ? :italic : nil
    end
    if (family = attributes['font-family']) && family.strip != ""
      font_updated = true
      @state[:font_family] = family
    end
    if (anchor = attributes['text-anchor'])
      @state[:text_anchor] = anchor
    end

    if @state[:font_family] && font_updated
      usable_font_families = [@state[:font_family], document.fallback_font_name]

      font_used = usable_font_families.compact.detect do |name|
        if font = Prawn::SVG::Font.load(name, @state[:font_weight], @state[:font_style])
          @state[:font_subfamily] = font.subfamily
          add_call_and_enter 'font', font.name, :style => @state[:font_subfamily]
          true
        end
      end

      if font_used.nil?
        warnings << "Font family '#{@state[:font_family]}' style '#{@state[:font_style] || 'normal'}' is not a known font, and the fallback font could not be found."
      end
    end
  end
end
