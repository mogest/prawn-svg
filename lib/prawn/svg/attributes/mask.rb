module Prawn::SVG::Attributes
  module Mask
    URI_REGEX = /\A\s*url\(#(.+)\)\s*\z/

    def parse_mask_and_call
      return unless matches = properties.mask&.match(URI_REGEX)
      id = matches[1]

      # TODO: need to look forward too? how do we do this elsewhere
      mask = document.elements_by_id[id]

      if mask && mask.class == Prawn::SVG::Elements::Mask
        mask.apply_mask(self)
      else
        @document.warnings << "mask ID '#{id}' not found, ignoring attribute"
      end
    end
  end
end
