module Prawn::SVG::CSS
  class FontFaceParser
    SUPPORTED_FORMATS = %w[truetype opentype].freeze

    class << self
      def parse_src(src)
        split_sources(src).filter_map { |entry| parse_source_entry(entry.strip) }
      end

      private

      def split_sources(value)
        entries = []
        current = +''
        depth = 0
        in_quote = nil

        value.each_char do |char|
          if in_quote
            current << char
            in_quote = nil if char == in_quote
          elsif ['"', "'"].include?(char)
            in_quote = char
            current << char
          elsif char == '('
            depth += 1
            current << char
          elsif char == ')'
            depth -= 1
            current << char
          elsif char == ',' && depth.zero?
            entries << current
            current = +''
          else
            current << char
          end
        end

        entries << current unless current.strip.empty?
        entries
      end

      def parse_source_entry(entry)
        parts = Prawn::SVG::CSS::ValuesParser.parse(entry)
        return if parts.empty?

        first = parts[0]
        return unless first.is_a?(Array)

        case first[0]
        when 'url'
          url = first[1][0]
          return unless url

          format = extract_format(parts[1])
          { type: :url, url: url, format: format }
        when 'local'
          name = first[1][0]
          return unless name

          { type: :local, name: name }
        end
      end

      def extract_format(part)
        return unless part.is_a?(Array) && part[0] == 'format'

        part[1][0]
      end
    end
  end
end
