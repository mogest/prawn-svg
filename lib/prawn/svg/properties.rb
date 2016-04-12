class Prawn::SVG::Properties
  Config = Struct.new(:default, :inheritable?, :keywords, :keyword_restricted?, :attr, :ivar)

  PROPERTIES = {
    "clip-path"        => Config.new("none", false, %w(inherit none)),
    "color"            => Config.new('', true),
    "display"          => Config.new("inline", false, %w(inherit inline none), true),
    "fill"             => Config.new("black", true),
    "fill-opacity"     => Config.new("1", true),
    "font-family"      => Config.new("sans-serif", true),
    "font-size"        => Config.new("medium", true),
    "font-style"       => Config.new("normal", true, %w(inherit normal italic oblique), true),
    "font-variant"     => Config.new("normal", true, %w(inherit normal small-caps), true),
    "font-weight"      => Config.new("normal", true, %w(inherit normal bold bolder lighter 100 200 300 400 500 600 700 800 900), true),
    "letter-spacing"   => Config.new("normal", true, %w(inherit normal)),
    "marker-end"       => Config.new("none", true, %w(inherit none)),
    "marker-mid"       => Config.new("none", true, %w(inherit none)),
    "marker-start"     => Config.new("none", true, %w(inherit none)),
    "opacity"          => Config.new("1", false),
    "overflow"         => Config.new('visible', false, %w(inherit visible hidden scroll auto), true),
    "stop-color"       => Config.new("black", false, %w(inherit currentColor)),
    "stroke"           => Config.new("none", true),
    "stroke-dasharray" => Config.new("none", true, %w(inherit none)),
    "stroke-linecap"   => Config.new("butt", true, %w(inherit butt round square)),
    "stroke-opacity"   => Config.new("1", true),
    "stroke-width"     => Config.new("1", true),
    "text-anchor"      => Config.new("start", true, %w(inherit start middle end), true),
  }.freeze

  PROPERTIES.each do |name, value|
    value.attr = name.gsub("-", "_")
    value.ivar = "@#{value.attr}"
  end

  PROPERTY_CONFIGS = PROPERTIES.values
  NAMES = PROPERTIES.keys
  ATTR_NAMES = PROPERTIES.keys.map { |name| name.gsub('-', '_') }

  attr_accessor *ATTR_NAMES

  def load_default_stylesheet
    PROPERTY_CONFIGS.each do |config|
      instance_variable_set(config.ivar, config.default)
    end

    self
  end

  def set(name, value)
    if config = PROPERTIES[name.to_s.downcase]
      value = value.strip
      keyword = value.downcase
      keywords = config.keywords || ['inherit']

      if keywords.include?(keyword)
        value = keyword
      elsif config.keyword_restricted?
        value = config.default
      end

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

      keyword = value.strip.downcase if value
      keyword = nil if keyword == ''

      if keyword && keyword != 'inherit'
        instance_variable_set(config.ivar, value)
      elsif keyword.nil? && !config.inheritable?
        instance_variable_set(config.ivar, config.default)
      end
    end
  end
end
