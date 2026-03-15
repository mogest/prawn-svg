module Prawn::SVG::CSS
  class Stylesheets
    attr_reader :css_parser, :root, :media, :font_face_rules

    def initialize(css_parser, root, media = :all, url_loader: nil, warnings: [])
      @css_parser = css_parser
      @root = root
      @media = media
      @warnings = warnings
      @font_face_rules = []

      @has_url_loader = !url_loader.nil?
      install_url_loader_on_css_parser(url_loader) if url_loader
    end

    def load
      load_style_elements
      xpath_styles = gather_xpath_styles
      associate_xpath_styles_with_elements(xpath_styles)
    end

    private

    def install_url_loader_on_css_parser(url_loader)
      warnings = @warnings

      css_parser.define_singleton_method(:load_uri!) do |uri, options = {}, _deprecated = nil|
        uri = Addressable::URI.parse(uri) unless uri.respond_to?(:scheme)
        import_url = uri.to_s

        begin
          return unless circular_reference_check(import_url)

          src = url_loader.load(import_url)
          add_block!(src, options) if src
        rescue CssParser::CircularReferenceError
          # Silently ignore circular @import references
        rescue Prawn::SVG::UrlLoader::Error => e
          warnings << "Failed to load @import CSS from #{import_url}: #{e.message}"
        end
      end
    end

    def load_style_elements
      options = @has_url_loader ? { base_uri: '' } : {}

      REXML::XPath.match(root, '//style').each do |source|
        data = source.texts.map(&:value).join
        css_parser.add_block!(data, **options)
      end
    end

    def gather_xpath_styles
      xpath_styles = []
      order = 0

      css_parser.each_rule_set(media) do |rule_set, _|
        declarations = []
        rule_set.each_declaration { |*data| declarations << data }

        rule_set.selectors.each do |selector_text|
          if selector_text.strip == '@font-face'
            @font_face_rules << declarations
            next
          end

          next unless (selector = Prawn::SVG::CSS::SelectorParser.parse(selector_text))

          xpath = css_selector_to_xpath(selector)
          specificity = calculate_specificity(selector)
          specificity << order
          order += 1

          xpath_styles << [xpath, declarations, specificity]
        end
      end

      xpath_styles.sort_by(&:last)
    end

    def associate_xpath_styles_with_elements(xpath_styles)
      element_styles = {}

      xpath_styles.each do |xpath, declarations, _|
        REXML::XPath.match(root, xpath).each do |element|
          (element_styles[element] ||= []).concat declarations
        end
      end

      element_styles
    end

    def xpath_quote(value)
      %("#{value.gsub('\\', '\\\\').gsub('"', '\\"')}") if value
    end

    RECOGNIZED_PSEUDO_CLASSES = %w[first-child last-child link visited hover active focus].freeze

    def css_selector_to_xpath(selector)
      selector.map do |element|
        pseudo_classes = Set.new(element[:pseudo_class])
        require_function_name = false
        never_match = false

        result = case element[:combinator]
                 when :child
                   +'/'
                 when :adjacent
                   pseudo_classes << 'first-child'
                   +'/following-sibling::'
                 when :siblings
                   +'/following-sibling::'
                 else
                   +'//'
                 end

        positions = []
        lang_predicates = []
        href_predicates = []
        pseudo_classes.each do |pc|
          case pc
          when 'first-child' then positions << '1'
          when 'last-child'  then positions << 'last()'
          when /^nth-child\((.+)\)$/ then positions << parse_nth_child_expression($1)
          when /^lang\((.+)\)$/ then lang_predicates << $1
          when 'link' then href_predicates << true
          when 'visited', 'hover', 'active', 'focus' then never_match = true
          else
            never_match = true unless RECOGNIZED_PSEUDO_CLASSES.include?(pc)
          end
        end

        unless positions.empty?
          result << '*' unless require_function_name
          require_function_name = true

          logic = if positions.length == 1
                    positions.first
                  else
                    positions.map { |position| "position()=#{position}" }.join(' and ')
                  end

          result << "[#{logic}]"
        end

        if require_function_name
          result << "[name()=#{xpath_quote element[:name]}]" if element[:name]
        else
          result << (element[:name] || '*')
        end

        result << ((element[:class] || []).map { |name| "[contains(concat(' ',@class,' '), ' #{name} ')]" }.join)
        result << ((element[:id] || []).map { |name| "[@id='#{name}']" }.join)

        (element[:attribute] || []).each do |key, operator, value|
          case operator
          when nil
            result << "[@#{key}]"
          when '='
            result << "[@#{key}=#{xpath_quote value}]"
          when '^='
            result << "[starts-with(@#{key}, #{xpath_quote value})]"
          when '$='
            result << "[substring(@#{key}, string-length(@#{key}) - #{value.length - 1}) = #{xpath_quote value}]"
          when '*='
            result << "[contains(@#{key}, #{xpath_quote value})]"
          when '~='
            result << "[contains(concat(' ',@#{key},' '), #{xpath_quote " #{value} "})]"
          when '|='
            result << "[contains(concat('-',@#{key},'-'), #{xpath_quote "-#{value}-"})]"
          end
        end

        lang_predicates.each do |lang|
          result << "[lang(#{xpath_quote lang})]"
        end

        result << '[@href or @xlink:href]' unless href_predicates.empty?

        result << '[false()]' if never_match

        result
      end.join
    end

    def parse_nth_child_expression(expr)
      expr = expr.strip

      return '(position() mod 2 = 1)' if expr == 'odd'
      return '(position() mod 2 = 0)' if expr == 'even'
      return expr if expr.match?(/\A\d+\z/)

      match = expr.match(/\A(-?\d*)n\s*([+-]\s*\d+)?\z/)
      return 'false()' unless match

      a = case match[1]
          when '', '+' then 1
          when '-' then -1
          else match[1].to_i
          end
      b = match[2] ? match[2].gsub(/\s/, '').to_i : 0

      if a.zero?
        b.to_s
      elsif a.positive?
        if b <= 0
          "(position() mod #{a} = #{b % a} and position() >= #{[b, 1].max})"
        else
          "(position() mod #{a} = #{b % a} and position() >= #{b})"
        end
      elsif b <= 0
        # a is negative: matches positions b, b+a, b+2a, ... while > 0
        # i.e. position() <= b and (position() - b) mod |a| = 0
        'false()'
      else
        "((position() - #{b}) mod #{a.abs} = 0 and position() >= 1 and position() <= #{b})"
      end
    end

    def calculate_specificity(selector)
      selector.reduce([0, 0, 0]) do |(a, b, c), element|
        [
          a + (element[:id] || []).length,
          b + (element[:class] || []).length + (element[:attribute] || []).length + (element[:pseudo_class] || []).length,
          c + (element[:name] && element[:name] != '*' ? 1 : 0)
        ]
      end
    end
  end
end
