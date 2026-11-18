module Prawn::SVG::Attributes::Mask
  def parse_mask_attribute_and_call
    mask_element = extract_element_from_url_id_reference(properties.mask, 'mask', 'mask')

    if mask_element
      add_call_and_enter 'save_graphics_state'
      mask_calls = mask_element.build_mask_calls(self)
      @calls << ['soft_mask', [], {}, mask_calls]
    end
  end
end
