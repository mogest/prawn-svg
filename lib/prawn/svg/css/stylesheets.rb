module Prawn::SVG::CSS
  class Stylesheets
    attr_reader :css_parser, :root, :media, :font_face_rules, :issues

    def initialize(css_parser, root, media = :all, load_url: nil, record_work: nil)
      @css_parser = css_parser
      @record_work = record_work
      @root = root
      @media = media
      @font_face_rules = []
      @issues = []
      @remote_base_urls = {}.compare_by_identity

      @load_url = load_url
      install_url_loader_on_css_parser(load_url) if load_url
    end

    def load
      load_style_elements
      associate_styles_with_elements(gather_styles)
    end

    private

    def install_url_loader_on_css_parser(load_url)
      issues = @issues
      remote_base_urls = @remote_base_urls
      without_invalid_imports = method(:without_invalid_imports)

      css_parser.define_singleton_method(:load_uri!) do |uri, options = {}, _deprecated = nil|
        uri = Addressable::URI.parse(uri) unless uri.respond_to?(:scheme)
        import_url = uri.to_s

        begin
          return unless circular_reference_check(import_url)

          if Prawn::SVG::UrlLoader.web_url?(options[:base_uri]) && !Prawn::SVG::UrlLoader.web_url?(import_url)
            issues << Prawn::SVG::Issue.new(:resource, "stylesheet from '#{options[:base_uri]}' may not @import '#{import_url}'")
            return
          end

          web = Prawn::SVG::UrlLoader.web_url?(import_url)
          src = load_url.call(import_url)
          src = without_invalid_imports.call(src, web ? import_url : options[:base_uri], "stylesheet from #{import_url}")

          if web
            existing = Set.new.compare_by_identity
            each_rule_set { |rule_set, _| existing << rule_set }
            add_block!(src, options.merge(base_uri: import_url))
            each_rule_set { |rule_set, _| remote_base_urls[rule_set] ||= import_url unless existing.include?(rule_set) }
          else
            add_block!(src, options)
          end
        rescue CssParser::CircularReferenceError
          # Silently ignore circular @import references
        rescue Prawn::SVG::UrlLoader::Error => e
          issues << Prawn::SVG::Issue.new(:resource, "Failed to load @import CSS from #{import_url}: #{e.message}")
        end
      end
    end

    def load_style_elements
      REXML::XPath.match(root, '//style').each do |source|
        data = source.texts.map(&:value).join

        if @load_url
          css_parser.add_block!(without_invalid_imports(data, '', 'stylesheet'), base_uri: '')
        else
          css_parser.add_block!(data)
        end
      end
    end

    # css_parser raises if it can't resolve an @import URL, discarding the rest of the stylesheet, so remove those
    # imports first, cleaning up and resolving them the same way it does.
    def without_invalid_imports(css, base_uri, description)
      css = css.encode('UTF-8', 'UTF-8', invalid: :replace, undef: :replace, replace: ' ')
      css = css.gsub(CssParser::Parser::STRIP_CSS_COMMENTS_RX, '').gsub(CssParser::Parser::STRIP_HTML_COMMENTS_RX, '')
      css.gsub(CssParser::Parser::RE_AT_IMPORT_RULE) do |rule|
        path = Regexp.last_match(1).delete(%('")).strip
        Addressable::URI.join(base_uri.to_s, path)
        rule
      rescue Addressable::URI::InvalidURIError => e
        issues << Prawn::SVG::Issue.new(:invalid, "#{description} has an invalid @import URL: #{e.message}")
        # Removing the rule entirely could join the text either side of it into a new @import rule.
        ' '
      end
    end

    def gather_styles
      styles = []
      order = 0

      css_parser.each_rule_set(media) do |rule_set, _|
        declarations = []
        rule_set.each_declaration { |*data| declarations << data }

        rule_set.selectors.each do |selector_text|
          if selector_text.strip == '@font-face'
            @font_face_rules << [declarations, @remote_base_urls[rule_set]]
            next
          end
          next if selector_text.lstrip.start_with?('@')

          unless (selector = Prawn::SVG::CSS::SelectorParser.parse(selector_text))
            issues << Prawn::SVG::Issue.new(:unsupported, "CSS selector '#{selector_text}' could not be parsed")
            next
          end

          specificity = calculate_specificity(selector)
          specificity << order
          order += 1

          styles << [selector, declarations, specificity]
        end
      end

      styles.sort_by(&:last)
    end

    def associate_styles_with_elements(styles)
      return {} if styles.empty?

      matcher = Prawn::SVG::CSS::SelectorMatcher.new(root)
      @record_work&.call(matcher.size * styles.sum { |selector, _| simple_selector_count(selector) } / 25)

      styles.each_with_object({}) do |(selector, declarations, _), element_styles|
        matcher.match(selector).each do |element|
          (element_styles[element] ||= []).concat declarations
        end
      end
    end

    def simple_selector_count(selector)
      selector.sum { |compound| 1 + compound.except(:combinator, :name).values.sum(&:length) }
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
