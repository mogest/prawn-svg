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

    FONT_STRETCH_MAPPING = {
      'ultra-condensed' => :ultra_condensed,
      'extra-condensed' => :extra_condensed,
      'condensed'       => :condensed,
      'semi-condensed'  => :semi_condensed,
      'normal'          => :normal,
      'semi-expanded'   => :semi_expanded,
      'expanded'        => :expanded,
      'extra-expanded'  => :extra_expanded,
      'ultra-expanded'  => :ultra_expanded
    }.freeze

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

    def load(family, weight = nil, style = nil, stretch = nil)
      weight = weight_for_css_font_weight(weight) unless FONT_WEIGHTS.include?(weight)
      stretch = stretch_for_css_font_stretch(stretch)

      CSS::FontFamilyParser.parse(family).detect do |name|
        name = name.gsub(/\s{2,}/, ' ')

        font = find_suitable_font(name, weight, style, stretch)
        break font if font
      end
    end

    private

    def find_suitable_font(name, weight, style, stretch)
      name = correctly_cased_font_name(name) || name

      name = GENERIC_CSS_FONT_MAPPING[name] if GENERIC_CSS_FONT_MAPPING.key?(name) && !installed_fonts.key?(name)

      return unless (subfamilies = installed_fonts[name])
      return if subfamilies.empty?

      if stretch && stretch != :normal
        font = find_with_weight_fallback(name, weight, style, stretch)
        return font if font

        font = find_with_weight_fallback(name, weight, nil, stretch) if style
        return font if font
      end

      font = find_with_weight_fallback(name, weight, style)
      return font if font

      if style
        font = find_with_weight_fallback(name, weight, nil)
        return font if font
      end

      Font.new(name, subfamilies.keys.first, nil)
    end

    def find_with_weight_fallback(name, weight, style, stretch = nil)
      current_weight = weight
      while current_weight
        font = Font.new(name, current_weight, style, stretch)
        return font if installed?(font)

        current_weight = FONT_WEIGHT_FALLBACKS[current_weight]
      end
      nil
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

    def stretch_for_css_font_stretch(stretch)
      return nil if stretch.nil?

      FONT_STRETCH_MAPPING[stretch] || :normal
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
          ttc = TTC.new(filename)
          if ttc.fonts.any?
            ttc.fonts.each do |font|
              subfamily = (font[:subfamily] || 'normal').gsub(/\s+/, '_').downcase.to_sym
              subfamily = :normal if subfamily == :regular
              (external_font_families[font[:family]] ||= {})[subfamily] ||= { file: filename, font: font[:index] }
            end
          else
            ttf = TTF.new(filename)
            next unless ttf.family

            subfamily = (ttf.subfamily || 'normal').gsub(/\s+/, '_').downcase.to_sym
            subfamily = :normal if subfamily == :regular
            (external_font_families[ttf.family] ||= {})[subfamily] ||= filename
          end
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
