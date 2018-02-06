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
        when Combinator
          result << {combinator: token.type}
          part = nil
        end
      end

      result
    end

    private

    VALID_CSS_IDENTIFIER_CHAR = /[a-zA-Z0-9_\u00a0-\uffff-]/
    Identifier = Struct.new(:name)
    Modifier = Struct.new(:type)
    Combinator = Struct.new(:type)

    def self.tokenise_css_selector(selector)
      result = []
      brackets = false

      selector.strip.chars do |char|
        if brackets
          result.last.name << char
          brackets = false if char == ')'
        elsif VALID_CSS_IDENTIFIER_CHAR.match(char)
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
          when ":"
            result << Modifier.new(:pseudo_class)
          when " "
            result << Combinator.new(:descendant) unless result.last.is_a?(Combinator)
          when ">"
            result.pop if result.last == Combinator.new(:descendant)
            result << Combinator.new(:child)
          when "+"
            result.pop if result.last == Combinator.new(:descendant)
            result << Combinator.new(:adjacent)
          when "~"
            result.pop if result.last == Combinator.new(:descendant)
            result << Combinator.new(:siblings)
          when "*"
            return unless result.empty? || result.last.is_a?(Combinator)
            result << Modifier.new(:name)
            result << Identifier.new("*")
          when "(" # e.g. :nth-child(3n+4)
            return unless result.last.is_a?(Identifier) && result[-2] && result[-2].is_a?(Modifier) && result[-2].type == :pseudo_class
            result.last.name << "("
            brackets = true
          else
            puts char
            return # unsupported Combinator
          end
        end
      end

      result unless brackets
    end
  end
end
