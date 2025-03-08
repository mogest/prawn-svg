module Prawn::SVG
  class Properties
    Config = Struct.new(:default, :inheritable?, :valid_values, :attr, :ivar, :id)

    EM = 16
    FONT_SIZES = {
      'xx-small' => EM / 4,
      'x-small'  => EM / 4 * 2,
      'small'    => EM / 4 * 3,
      'medium'   => EM / 4 * 4,
      'large'    => EM / 4 * 5,
      'x-large'  => EM / 4 * 6,
      'xx-large' => EM / 4 * 7
    }.freeze

    PROPERTIES = {
      'clip-path'         => Config.new('none', false, ['none', :funciri]),
      'color'             => Config.new(Color.black, true, [:color]),
      'display'           => Config.new('inline', false, %w[inline none]),
      'dominant-baseline' => Config.new('auto', true, %w[auto middle]),
      'fill'              => Config.new(Paint.black, true, [:paint]),
      'fill-opacity'      => Config.new(1.0, true, [:number]),
      'fill-rule'         => Config.new('nonzero', true, %w[nonzero evenodd]),
      'font-family'       => Config.new('sans-serif', true, [:any]),
      # Only the computed (numeric) value of font-size is inherited, not the value itself
      'font-size'         => Config.new(nil, false,
        [:positive_length, :positive_percentage, 'xx-small', 'x-small', 'small', 'medium', 'large', 'x-large', 'xx-large', 'larger', 'smaller']),
      'font-style'        => Config.new('normal', true, %w[normal italic oblique]),
      'font-variant'      => Config.new('normal', true, %w[normal small-caps]),
      'font-weight'       => Config.new('normal', true, %w[normal bold 100 200 300 400 500 600 700 800 900]), # bolder/lighter not supported
      'letter-spacing'    => Config.new('normal', true, [:length, 'normal']),
      'marker-end'        => Config.new('none', true, [:funciri, 'none']),
      'marker-mid'        => Config.new('none', true, [:funciri, 'none']),
      'marker-start'      => Config.new('none', true, [:funciri, 'none']),
      'opacity'           => Config.new(1.0, false, [:number]),
      'overflow'          => Config.new('visible', false, %w[visible hidden scroll auto]),
      'stop-color'        => Config.new(Color.black, false, [:color_with_icc, 'currentcolor']),
      'stop-opacity'      => Config.new(1.0, false, [:number]),
      'stroke'            => Config.new(Paint.none, true, [:paint]),
      'stroke-dasharray'  => Config.new('none', true, [:dasharray, 'none']),
      'stroke-linecap'    => Config.new('butt', true, %w[butt round square]),
      'stroke-linejoin'   => Config.new('miter', true, %w[miter round bevel]),
      'stroke-opacity'    => Config.new(1.0, true, [:number]),
      'stroke-width'      => Config.new(1.0, true, [:positive_length, :positive_percentage]),
      'text-anchor'       => Config.new('start', true, %w[start middle end]),
      'text-decoration'   => Config.new('none', true, %w[none underline]),
      'visibility'        => Config.new('visible', true, %w[visible hidden collapse])
    }.freeze

    PROPERTIES.each do |name, value|
      value.attr = name.gsub('-', '_')
      value.id = value.attr.to_sym
      value.ivar = "@#{value.attr}"
    end

    PROPERTY_CONFIGS = PROPERTIES.values
    NAMES = PROPERTIES.keys
    ATTR_NAMES = PROPERTIES.keys.map { |name| name.gsub('-', '_') }

    attr_accessor(*ATTR_NAMES)
    attr_reader :important_ids

    def initialize
      @numeric_font_size = EM
      @important_ids = []
    end

    def load_default_stylesheet
      PROPERTY_CONFIGS.each do |config|
        instance_variable_set(config.ivar, config.default)
      end

      self
    end

    def set(name, value, important: false)
      name = name.to_s.downcase
      if (config = PROPERTIES[name])
        if (value = parse_value(config, value.strip)) && (important || !@important_ids.include?(config.id))
          @important_ids << config.id if important
          instance_variable_set(config.ivar, value)
        end
      elsif name == 'font'
        apply_font_shorthand(value)
      end
    end

    def numeric_font_size
      @numeric_font_size or raise 'numeric_font_size not set; this is only present in computed properties'
    end

    def to_h
      PROPERTIES.each.with_object({}) do |(name, config), result|
        result[name] = instance_variable_get(config.ivar)
      end
    end

    def load_hash(hash)
      hash.each { |name, value| set(name, value) if value }
    end

    def compute_properties(other)
      PROPERTY_CONFIGS.each do |config|
        value = other.send(config.attr)

        if value && value != 'inherit' && (!@important_ids.include?(config.id) || other.important_ids.include?(config.id))
          instance_variable_set(config.ivar, value)

        elsif value.nil? && !config.inheritable?
          instance_variable_set(config.ivar, config.default)
        end
      end

      @important_ids += other.important_ids
      @numeric_font_size = calculate_numeric_font_size
      nil
    end

    private

    def calculate_numeric_font_size
      case font_size
      when Length
        font_size.to_pixels(nil, numeric_font_size)
      when Percentage
        font_size.to_factor * numeric_font_size
      when Numeric
        font_size
      when 'larger'
        numeric_font_size + 4
      when 'smaller'
        numeric_font_size - 4
      when nil, 'inherit'
        numeric_font_size
      when String
        FONT_SIZES[font_size] or raise "Unknown font size keyword: #{font_size}"
      else
        raise "Unknown font size property value: #{font_size.inspect}"
      end
    end

    def parse_value(config, value)
      keyword = value.downcase

      return 'inherit' if keyword == 'inherit'

      config.valid_values.detect do |type|
        result = parse_value_with_type(type, value, keyword)
        break result if result
      end
    end

    def parse_value_with_type(type, value, keyword)
      case type
      when String
        keyword if type == keyword
      when :color
        values = Prawn::SVG::CSS::ValuesParser.parse(value)
        Prawn::SVG::Color.parse(values[0]) if values.length == 1
      when :color_with_icc
        case Prawn::SVG::CSS::ValuesParser.parse(value)
        in [other, ['icc-color', _args]]
          Prawn::SVG::Color.parse(other)
        in [other] # rubocop:disable Lint/DuplicateBranch
          Prawn::SVG::Color.parse(other)
        else
          nil
        end
      when :paint
        Paint.parse(value)
      when :funciri
        FuncIRI.parse(value)
      when :dasharray
        value.split(Prawn::SVG::Elements::COMMA_WSP_REGEXP).map do |value|
          Length.parse(value) || Percentage.parse(value) || break
        end
      when :number
        Float(value, exception: false)
      when :length
        Length.parse(value)
      when :percentage
        Percentage.parse(value)
      when :positive_length
        Length.parse(value, positive_only: true)
      when :positive_percentage
        Percentage.parse(value, positive_only: true)
      when :any
        value
      else
        raise "Unknown valid value type: #{type}"
      end
    end

    FONT_KEYWORD_MAPPING = ['font-style', 'font-variant', 'font-weight'].each.with_object({}) do |property, result|
      PROPERTIES[property].valid_values.each do |value|
        result[value] = property
      end
    end

    def apply_font_shorthand(value)
      if value.strip.match(/\s/).nil?
        case value.strip.downcase
        when 'inherit'
          load_hash('font-style' => 'inherit', 'font-variant' => 'inherit', 'font-weight' => 'inherit', 'font-size' => 'inherit', 'font-family' => 'inherit')
        when 'caption', 'icon', 'menu', 'message-box', 'small-caption', 'status-bar'
          load_hash('font-style' => 'normal', 'font-variant' => 'normal', 'font-weight' => 'normal', 'font-size' => 'medium', 'font-family' => 'sans-serif')
        end

        return
      end

      properties = ['font-style', 'font-variant', 'font-weight'].each.with_object({}) do |property, result|
        result[property] = PROPERTIES[property].default
      end

      values = CSS::FontParser.parse(value)
      return if values.length < 2

      properties['font-family'] = values.pop
      font_size = values.pop.sub(%r{/.*}, '')

      values.each do |keyword|
        keyword = keyword.downcase
        if (property = FONT_KEYWORD_MAPPING[keyword])
          properties[property] = keyword
        else
          break
        end
      end or return

      set('font-size', font_size) or return
      load_hash(properties)
      value
    end
  end
end
