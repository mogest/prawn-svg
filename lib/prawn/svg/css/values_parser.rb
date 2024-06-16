module Prawn::SVG::CSS
  class ValuesParser
    class << self
      def parse(values)
        result = []

        while values
          value, remainder = parse_next(values)
          break unless value

          result << value
          values = remainder
        end

        result
      end

      private

      def parse_next(values)
        values = values.strip
        return if values.empty?

        if (matches = values.match(/\A([a-z-]+)\(\s*(.+)/i))
          parse_function_call(matches[1].downcase, matches[2])
        else
          values.split(/\s+/, 2)
        end
      end

      # Note this does not support space-separated arguments.
      # I don't think CSS 2 has any, but in case it does here is the place to add them.
      def parse_function_call(name, rest)
        arguments = []
        in_quote = nil
        in_escape = false
        current = +''

        rest.each_char.with_index do |char, index|
          if in_escape
            current << char
            in_escape = false
          elsif %w[" '].include?(char)
            if in_quote == char
              in_quote = nil
            elsif in_quote.nil?
              in_quote = char
            else
              current << char
            end
          elsif char == '\\'
            in_escape = true
          elsif in_quote.nil? && char == ','
            arguments << current.strip
            current = +''
          elsif in_quote.nil? && char == ')'
            arguments << current.strip
            return [[name, arguments], rest[index + 1..]]
          else
            current << char
          end
        end

        [rest, nil]
      end
    end
  end
end
