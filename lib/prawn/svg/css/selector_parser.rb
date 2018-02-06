module Prawn::SVG::CSS
  class SelectorParser
    def self.parse(selector)
      tokens = tokenise_css_selector(selector) or return

      result = [{}]
      part = nil

      tokens.each do |token|
        case token
        when Modifier
          part = token.type
          result.last[part] ||= part == :name ? "" : []
        when Identifier
          return unless part
          result.last[part] << token.name
        when Association
          result << {association: token.type}
          part = nil
        end
      end

      result
    end

    private

    VALID_CSS_IDENTIFIER_CHAR = /[a-zA-Z0-9_\u00a0-\uffff-]/
    Identifier = Struct.new(:name)
    Modifier = Struct.new(:type)
    Association = Struct.new(:type)

    def self.tokenise_css_selector(selector)
      result = []

      selector.strip.chars do |char|
        if VALID_CSS_IDENTIFIER_CHAR.match(char)
          case result.last
          when Identifier
            result.last.name << char
          else
            result << Modifier.new(:name) if !result.last.is_a?(Modifier)
            result << Identifier.new(char)
          end
        else
          case char
          when "."
            result << Modifier.new(:class)
          when "#"
            result << Modifier.new(:id)
          when " "
            result << Association.new(:descendant) unless result.last.is_a?(Association)
          when ">"
            result.pop if result.last == Association.new(:descendant)
            result << Association.new(:child)
          when "*"
            return unless result.empty? || result.last.is_a?(Association)
            result << Modifier.new(:name)
            result << Identifier.new("*")
          else
            puts char
            return # unsupported association
          end
        end
      end

      result
    end
  end
end
