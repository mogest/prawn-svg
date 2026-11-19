module Prawn::SVG::CSS
  # Matches a selector one compound selector at a time, each a single pass over the elements, so the time taken is
  # proportional to the number of elements however the selector's combinators nest.
  class SelectorMatcher
    Node = Struct.new(:element, :parent, :previous, :position, :last, :attributes, :classes, :lang)

    NTH_CHILD_FORMULA = /\A(?:([+-]?\d*)n)?\s*(?:([+-]?)\s*(\d+))?\z/.freeze

    # Nodes are indexed breadth first, so each node's parent and previous sibling come before it.  Attributes are
    # copied out because REXML walks up to the document on every lookup of an attribute that isn't there.
    def initialize(root)
      @nodes = [new_node(root, nil, nil, 1, true)]

      @nodes.each_with_index do |node, index|
        children = node.element.children.grep(REXML::Element)
        children.each_with_index do |child, position|
          previous = @nodes.length - 1 unless position.zero?
          @nodes << new_node(child, index, previous, position + 1, position == children.length - 1)
        end
      end
    end

    def size
      @nodes.length
    end

    def match(selector)
      matched = selector.reduce(nil) do |previous, compound|
        related = previous ? related(previous, compound[:combinator]) : Array.new(@nodes.length, true)
        pseudo_classes = (compound[:pseudo_class] || []).map { |pseudo_class| compile_pseudo_class(pseudo_class) }
        @nodes.each_with_index.map { |node, index| related[index] && matches?(node, compound, pseudo_classes) }
      end

      @nodes.select.with_index { |_, index| matched[index] }.map(&:element)
    end

    private

    def new_node(element, parent, previous, position, last)
      attributes = {}
      element.attributes.each_attribute { |attribute| attributes[attribute.expanded_name] = attribute.value }
      lang = attributes['xml:lang']&.downcase || (@nodes[parent].lang if parent)

      Node.new(element, parent, previous, position, last, attributes, attributes['class'].to_s.split.to_set, lang)
    end

    def related(matched, combinator)
      @nodes.each_with_object([]) do |node, result|
        result << case combinator
                  when :child    then node.parent && matched[node.parent]
                  when :adjacent then node.previous && matched[node.previous]
                  when :siblings then node.previous && (matched[node.previous] || result[node.previous])
                  else                node.parent && (matched[node.parent] || result[node.parent])
                  end
      end
    end

    def matches?(node, compound, pseudo_classes)
      [nil, '*', node.element.name].include?(compound[:name]) &&
        (compound[:id] || []).all? { |id| node.attributes['id'] == id } &&
        (compound[:class] || []).all? { |name| node.classes.include?(name) } &&
        (compound[:attribute] || []).all? { |key, operator, value| attribute_matches?(node.attributes[key], operator, value) } &&
        pseudo_classes.all? { |pseudo_class| pseudo_class.call(node) }
    end

    def attribute_matches?(actual, operator, value)
      return false if actual.nil?

      case operator
      when nil  then true
      when '='  then actual == value
      when '~=' then actual.split.include?(value)
      when '|=' then actual == value || actual.start_with?("#{value}-")
      when '^=' then !value.empty? && actual.start_with?(value)
      when '$=' then !value.empty? && actual.end_with?(value)
      when '*=' then !value.empty? && actual.include?(value)
      end
    end

    def compile_pseudo_class(pseudo_class)
      case pseudo_class
      when 'first-child' then ->(node) { node.position == 1 }
      when 'last-child'  then lambda(&:last)
      when 'link'        then ->(node) { node.attributes.key?('href') || node.attributes.key?('xlink:href') }
      when /\Anth-child\((.*)\)\z/
        a, b = nth_child_formula(Regexp.last_match(1).strip.downcase)
        return ->(_) { false } unless a

        ->(node) { a.zero? ? node.position == b : ((node.position - b) % a).zero? && (node.position - b) / a >= 0 }
      when /\Alang\((.*)\)\z/
        lang = Regexp.last_match(1).downcase
        ->(node) { node.lang == lang || !!node.lang&.start_with?("#{lang}-") }
      else ->(_) { false }
      end
    end

    def nth_child_formula(expression)
      match = NTH_CHILD_FORMULA.match({ 'odd' => '2n+1', 'even' => '2n' }.fetch(expression, expression)) or return

      a = case match[1]
          when nil then 0
          when '', '+' then 1
          when '-' then -1
          else match[1].to_i
          end
      [a, "#{match[2]}#{match[3]}".to_i]
    end
  end
end
