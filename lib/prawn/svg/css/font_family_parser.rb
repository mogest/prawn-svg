module Prawn::SVG::CSS
  class FontFamilyParser
    def self.parse(string)
      in_quote = nil
      in_escape = false
      current = nil
      fonts = []

      string.each_char do |char|
        if in_escape
          in_escape = false
          if current.nil?
            current = char
            fonts << current
          else
            current << char
          end
        elsif char == ',' && in_quote.nil?
          current = nil
        elsif char == in_quote
          in_quote = nil
        elsif in_quote.nil? && ['"', "'"].include?(char)
          in_quote = char
        elsif char == '\\'
          in_escape = true
        elsif current.nil?
          if char.match(/\s/).nil?
            current = char
            fonts << current
          end
        else
          current << char
        end
      end

      fonts.map(&:rstrip)
    end
  end
end
