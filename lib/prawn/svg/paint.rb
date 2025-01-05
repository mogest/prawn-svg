module Prawn::SVG
  Paint = Struct.new(:color, :url) do
    class << self
      def none
        new(:none, nil)
      end

      def black
        new(Color.black, nil)
      end

      def parse(value)
        case CSS::ValuesParser.parse(value)
        in [['url', [url]]]
          # If there is no fallback color, and the URL is unresolvable, the spec says that the document is in error.
          # Chrome appears to treat this the same as an explicit 'none', so we do the same.
          new(:none, url)
        in [['url', [url]], keyword_or_color]
          parse_keyword_or_color(keyword_or_color, url)
        in [['url', [url]], keyword_or_color, ['icc-color', _args]] # rubocop:disable Lint/DuplicateBranch
          parse_keyword_or_color(keyword_or_color, url)
        in [keyword_or_color, ['icc-color', _args]]
          parse_keyword_or_color(keyword_or_color, nil)
        in [keyword_or_color] # rubocop:disable Lint/DuplicateBranch
          parse_keyword_or_color(keyword_or_color, nil)
        else
          nil
        end
      end

      private

      def parse_keyword_or_color(value, url)
        if value.is_a?(String)
          keyword = value.downcase
          return new(keyword.to_sym, url) if ['none', 'currentcolor'].include?(keyword)
        end

        color = Color.parse(value)
        new(color, url) if color
      end
    end

    def none?
      color == :none && (url.nil? || !!@unresolved_url)
    end

    def resolve(gradients, current_color, color_mode)
      if url
        if url[0] == '#' && gradients && (gradient = gradients[url[1..]])
          return gradient
        else
          @unresolved_url = true
        end
      end

      case color
      when :currentcolor
        current_color
      when :none
        nil
      else
        color_mode == :cmyk ? color.to_cmyk : color
      end
    end
  end
end
