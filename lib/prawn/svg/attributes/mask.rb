module Prawn::SVG::Attributes::Mask
  def parse_mask_attribute_and_call
    return unless (mask = properties.mask)
    return if mask == 'none'

    mask_element = extract_element_from_url_id_reference(mask, 'mask')

    if mask_element.nil?
      document.warnings << 'Could not resolve mask URI to a mask element'
    else
      add_call_and_enter 'save_graphics_state'
      mask_calls = mask_element.build_mask_calls(self)
      @calls << ['soft_mask', [], {}, mask_calls]
    end
  end
end
