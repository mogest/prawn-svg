module Prawn::SVG::Attributes::ClipPath
  def parse_clip_path_attribute_and_call
    return unless (clip_path = properties.clip_path)
    return if clip_path == 'none'

    clip_path_element = extract_element_from_url_id_reference(clip_path, 'clipPath')

    if clip_path_element.nil?
      document.warnings << 'Could not resolve clip-path URI to a clipPath element'
    else
      clip_calls = clip_path_element.build_clip_calls(self)
      return if clip_calls.nil?

      add_call_and_enter 'save_graphics_state'
      @calls.concat clip_calls

      # SVG's clip-rule applies per-element (determining each shape's interior),
      # then elements are unioned. PDF's W* applies even-odd to the entire combined
      # path, which incorrectly creates holes between separate shapes. Only use W*
      # when there's a single child element, where self-intersection matters.
      child_elements = clip_path_element.svg_child_elements
      if child_elements.length == 1 && clip_path_element.computed_properties.clip_rule == 'evenodd'
        add_call 'clip', clip_rule: :even_odd
      else
        add_call 'clip'
      end
    end
  end
end
