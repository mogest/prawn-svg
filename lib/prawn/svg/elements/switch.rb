class Prawn::SVG::Elements::Switch < Prawn::SVG::Elements::Base
  def container?
    true
  end

  def process_child_elements
    return unless source

    elem = svg_child_elements.find do |e|
      passes_conditional_processing?(e) && Prawn::SVG::Elements::TAG_CLASS_MAPPING[e.name.to_sym]
    end

    return unless elem

    element_class = Prawn::SVG::Elements::TAG_CLASS_MAPPING[elem.name.to_sym]
    add_call 'save'
    child = element_class.new(@document, elem, @calls, state.dup)
    child.process
    add_call 'restore'
  end
end
