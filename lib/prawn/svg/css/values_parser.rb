require 'strscan'

module Prawn::SVG::CSS
  class ValuesParser
    class << self
      def parse(values)
        scanner = StringScanner.new(values)
        result = []

        until scanner.skip(/\s*/) && scanner.eos?
          if (name = scanner.scan(/[a-z-]+(?=\()/i))
            scanner.skip(/\(\s*/)
            result << [name.downcase, parse_arguments(scanner)]
          else
            result << scanner.scan(/\S+/)
          end
        end

        result
      end

      private

      # Note this does not support space-separated arguments.
      # I don't think CSS 2 has any, but in case it does here is the place to add them.
      # As in CSS, a function call that is not closed ends at the end of the values.
      def parse_arguments(scanner)
        arguments = []
        in_quote = nil
        current = +''

        while (char = scanner.getch)
          if char == '\\'
            current << scanner.getch.to_s
          elsif ['"', "'"].include?(char)
            if in_quote == char
              in_quote = nil
            elsif in_quote.nil?
              in_quote = char
            else
              current << char
            end
          elsif in_quote.nil? && char == ','
            arguments << current.strip
            current = +''
          elsif in_quote.nil? && char == ')'
            break
          else
            current << char
          end
        end

        arguments << current.strip
      end
    end
  end
end
