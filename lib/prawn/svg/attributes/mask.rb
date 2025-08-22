module Prawn::SVG::Attributes
  module Mask
    URI_REGEX = /\A\s*url\(#(.+)\)\s*\z/

    def parse_mask_and_call
      mask_element = extract_element_from_url_id_reference(properties.mask, 'mask')

      if mask_element
        mask_element.apply_mask(self)
      elsif properties.mask && properties.mask != 'none'
        @document.warnings << "Could not resolve mask URI to a mask element"
      end
    end
  end
end
