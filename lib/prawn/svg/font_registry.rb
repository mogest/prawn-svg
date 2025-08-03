module Prawn::SVG
  class FontRegistry
    GENERIC_CSS_FONT_MAPPING = {
      'serif'      => 'Times-Roman',
      'sans-serif' => 'Helvetica',
      'cursive'    => 'Times-Roman',
      'fantasy'    => 'Times-Roman',
      'monospace'  => 'Courier'
    }.freeze

    FONT_WEIGHT_FALLBACKS = {
      light:     :normal,
      normal:    nil,
      semibold:  :bold,
      bold:      :normal,
      extrabold: :bold,
      black:     :extrabold
    }.freeze

    FONT_WEIGHTS = FONT_WEIGHT_FALLBACKS.keys.freeze

    DEFAULT_FONT_PATHS = [
      '/Library/Fonts',
      '/System/Library/Fonts',
      "#{Dir.home}/Library/Fonts",
      '/usr/share/fonts/truetype',
      '/mnt/c/Windows/Fonts' # Bash on Ubuntu on Windows
    ].freeze

    @font_path = DEFAULT_FONT_PATHS.select { |path| Dir.exist?(path) }

    def initialize(font_families)
      @font_families = font_families
    end

    def installed_fonts
      merge_external_fonts
      @font_families
    end

    def correctly_cased_font_name(name)
      merge_external_fonts
      @font_case_mapping[name.downcase]
    end

    def load(family, weight = nil, style = nil)
      weight = weight_for_css_font_weight(weight) unless FONT_WEIGHTS.include?(weight)

      CSS::FontFamilyParser.parse(family).detect do |name|
        name = name.gsub(/\s{2,}/, ' ')

        font = find_suitable_font(name, weight, style)
        break font if font
      end
    end

    private

    def find_suitable_font(name, weight, style)
      name = correctly_cased_font_name(name) || name
      name = GENERIC_CSS_FONT_MAPPING[name] if GENERIC_CSS_FONT_MAPPING.key?(name)

      return unless (subfamilies = installed_fonts[name])
      return if subfamilies.empty?

      while weight
        font = Font.new(name, weight, style)
        return font if installed?(font)

        weight = FONT_WEIGHT_FALLBACKS[weight]
      end

      if style
        find_suitable_font(name, weight, nil) unless style.nil?
      else
        Font.new(name, subfamilies.keys.first, nil)
      end
    end

    def installed?(font)
      subfamilies = installed_fonts[font.name]
      !subfamilies.nil? && subfamilies.key?(font.subfamily)
    end

    def weight_for_css_font_weight(weight)
      case weight
      when '100', '200', '300'    then :light
      when '400', '500', 'normal' then :normal
      when '600'                  then :semibold
      when '700', 'bold'          then :bold
      when '800'                  then :extrabold
      when '900'                  then :black
      else :normal # rubocop:disable Lint/DuplicateBranch
      end
    end

    def merge_external_fonts
      if @font_case_mapping.nil?
        self.class.load_external_fonts unless self.class.external_font_families
        @font_families.merge!(self.class.external_font_families) do |_key, v1, _v2|
          v1
        end
        @font_case_mapping = @font_families.keys.each.with_object({}) do |key, result|
          result[key.downcase] = key
        end
        GENERIC_CSS_FONT_MAPPING.each_key do |generic|
          @font_case_mapping[generic] = generic
        end
      end
    end

    class << self
      attr_reader :external_font_families, :font_path

      def load_external_fonts
        @external_font_families = {}

        external_font_paths.each do |filename|
          ttf = TTF.new(filename)
          next unless ttf.family

          subfamily = (ttf.subfamily || 'normal').gsub(/\s+/, '_').downcase.to_sym
          subfamily = :normal if subfamily == :regular
          (external_font_families[ttf.family] ||= {})[subfamily] ||= filename
        end
      end

      private

      def external_font_paths
        font_path
          .uniq
          .flat_map { |path| Dir["#{path}/**/*"] }
          .uniq
          .select { |path| File.file?(path) }
      end
    end
  end
end
