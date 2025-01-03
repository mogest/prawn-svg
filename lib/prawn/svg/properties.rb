class Prawn::SVG::Properties
  Config = Struct.new(:default, :inheritable?, :valid_values, :attr, :ivar)

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
    'color'             => Config.new('', true, [:color]),
    'display'           => Config.new('inline', false, %w[inline none]),
    'fill'              => Config.new('black', true, ['none', 'currentcolor', :paint]),
    'fill-opacity'      => Config.new('1', true, [:number]),
    'fill-rule'         => Config.new('nonzero', true, %w[nonzero evenodd]),
    'font-family'       => Config.new('sans-serif', true, [:any]),
    'font-size'         => Config.new('medium', true,
      [:positive_length, :positive_percentage, 'xx-small', 'x-small', 'small', 'medium', 'large', 'x-large', 'xx-large', 'larger', 'smaller']),
    'font-style'        => Config.new('normal', true, %w[normal italic oblique]),
    'font-variant'      => Config.new('normal', true, %w[normal small-caps]),
    'font-weight'       => Config.new('normal', true, %w[normal bold 100 200 300 400 500 600 700 800 900]), # bolder/lighter not supported
    'letter-spacing'    => Config.new('normal', true, [:length, 'normal']),
    'marker-end'        => Config.new('none', true, [:funciri, 'none']),
    'marker-mid'        => Config.new('none', true, [:funciri, 'none']),
    'marker-start'      => Config.new('none', true, [:funciri, 'none']),
    'opacity'           => Config.new('1', false, [:number]),
    'overflow'          => Config.new('visible', false, %w[visible hidden scroll auto]),
    'stop-color'        => Config.new('black', false, [:color_with_lcc, 'currentcolor']),
    'stop-opacity'      => Config.new('1', false, [:number]),
    'stroke'            => Config.new('none', true, ['none', 'currentcolor', :paint]),
    'stroke-dasharray'  => Config.new('none', true, [:dasharray, 'none']),
    'stroke-linecap'    => Config.new('butt', true, %w[butt round square]),
    'stroke-linejoin'   => Config.new('miter', true, %w[miter round bevel]),
    'stroke-opacity'    => Config.new('1', true, [:number]),
    'stroke-width'      => Config.new('1', true, [:positive_length, :positive_percentage]),
    'text-anchor'       => Config.new('start', true, %w[start middle end]),
    'text-decoration'   => Config.new('none', true, %w[none underline]),
    'dominant-baseline' => Config.new('auto', true, %w[auto middle])
  }.freeze

  PROPERTIES.each do |name, value|
    value.attr = name.gsub('-', '_')
    value.ivar = "@#{value.attr}"
  end

  PROPERTY_CONFIGS = PROPERTIES.values
  NAMES = PROPERTIES.keys
  ATTR_NAMES = PROPERTIES.keys.map { |name| name.gsub('-', '_') }

  attr_accessor(*ATTR_NAMES)

  def load_default_stylesheet
    PROPERTY_CONFIGS.each do |config|
      instance_variable_set(config.ivar, config.default)
    end

    self
  end

  def set(name, value)
    if (config = PROPERTIES[name.to_s.downcase]) && (value = parse_value(config, value.strip))
      instance_variable_set(config.ivar, value)
    end
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

      if value && value != 'inherit'
        value = compute_font_size_property(value).to_s if config.attr == 'font_size'
        instance_variable_set(config.ivar, value)

      elsif value.nil? && !config.inheritable?
        instance_variable_set(config.ivar, config.default)
      end
    end
  end

  def numerical_font_size
    # px = pt for PDFs
    FONT_SIZES[font_size] || font_size.to_f
  end

  private

  def compute_font_size_property(value)
    if value[-1] == '%'
      numerical_font_size * (value.to_f / 100.0)
    elsif value == 'larger'
      numerical_font_size + 4
    elsif value == 'smaller'
      numerical_font_size - 4
    elsif value.match(/(\d|\.)em\z/i)
      numerical_font_size * value.to_f
    elsif value.match(/(\d|\.)rem\z/i)
      value.to_f * EM
    else
      FONT_SIZES[value] || value.to_f
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

  NUMBER_REGEXP = /\A[+-]?\d*(\.\d+)?\z/.freeze
  LENGTH_REGEXP = /\A[+-]?\d*(\.\d+)?(em|ex|px|in|cm|mm|pt|pc)?\z/i.freeze
  PERCENTAGE_REGEXP = /\A[+-]?\d*(\.\d+)?%\z/.freeze
  POSITIVE_LENGTH_REGEXP = /\A+?\d*(\.\d+)?(em|ex|px|in|cm|mm|pt|pc)?\z/i.freeze
  POSITIVE_PERCENTAGE_REGEXP = /\A+?\d*(\.\d+)?%\z/.freeze

  def parse_value_with_type(type, value, keyword)
    case type
    when String
      type == keyword ? keyword : nil
    when :color
      values = Prawn::SVG::CSS::ValuesParser.parse(value)
      if values.length == 1
        Prawn::SVG::Color.parse_color(values[0]) ? value : nil
      end
    when :funciri
      case Prawn::SVG::CSS::ValuesParser.parse(value)
      in [['url', [_url]]]
        value
      else
        nil
      end
    when :paint
      case Prawn::SVG::CSS::ValuesParser.parse(value)
      in [['url', [_url]]]
        value
      in [['url', [_url]], other]
        ['none', 'currentcolor'].include?(other.downcase) || Prawn::SVG::Color.parse_color(other) ? value : nil
      in [['url', [_url]], other, ['icc-color', _args]] # rubocop:disable Lint/DuplicateBranch
        ['none', 'currentcolor'].include?(other.downcase) || Prawn::SVG::Color.parse_color(other) ? value : nil
      in [other, ['icc-color', _args]]
        Prawn::SVG::Color.parse_color(other) ? value : nil
      in [other] # rubocop:disable Lint/DuplicateBranch
        Prawn::SVG::Color.parse_color(other) ? value : nil
      else
        nil
      end
    when :color_with_lcc
      case Prawn::SVG::CSS::ValuesParser.parse(value)
      in [other, ['icc-color', _args]]
        Prawn::SVG::Color.parse_color(other) ? value : nil
      in [other] # rubocop:disable Lint/DuplicateBranch
        Prawn::SVG::Color.parse_color(other) ? value : nil
      else
        nil
      end
    when :dasharray
      values = value.split(Prawn::SVG::Elements::COMMA_WSP_REGEXP)
      values.all? { |value| value.match(POSITIVE_LENGTH_REGEXP) || value.match(POSITIVE_PERCENTAGE_REGEXP) } ? value : nil
    when :number
      value.match(NUMBER_REGEXP) ? value : nil
    when :length
      value.match(LENGTH_REGEXP) ? value : nil
    when :percentage
      value.match(PERCENTAGE_REGEXP) ? value : nil
    when :positive_length
      value.match(POSITIVE_LENGTH_REGEXP) ? value : nil
    when :positive_percentage
      value.match(POSITIVE_PERCENTAGE_REGEXP) ? value : nil
    when :any
      value
    else
      raise "Unknown valid value type: #{type}"
    end
  end
end
