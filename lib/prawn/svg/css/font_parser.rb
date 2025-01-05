module Prawn::SVG::CSS
  class FontParser
    def self.parse(string)
      in_quote = nil
      in_escape = false
      in_list_delimiter = false
      current = nil
      values = []

      string.each_char do |char|
        if in_escape
          in_escape = false
          if current.nil?
            current = char
            values << current
          else
            current << char
          end
        elsif char == ',' && in_quote.nil? && !in_escape && current
          current << char
          in_list_delimiter = true
        elsif char == '\\'
          in_escape = true
        elsif current.nil?
          if char.match(/\s/).nil?
            in_list_delimiter = false
            current = char
            values << current
          end
        elsif !in_quote && !in_escape && !in_list_delimiter && char.match(/\s/)
          current = nil
        else
          current << char
        end

        if char == in_quote
          in_quote = nil
        elsif in_quote.nil? && ['"', "'"].include?(char)
          in_quote = char
        end
      end

      values.map(&:rstrip)
    end
  end
end
