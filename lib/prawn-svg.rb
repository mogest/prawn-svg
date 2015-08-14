require 'rexml/document'

require 'prawn'
require 'prawn/svg/version'

require 'prawn/svg/calculators/aspect_ratio'
require 'prawn/svg/calculators/document_sizing'
require 'prawn/svg/calculators/pixels'
require 'prawn/svg/url_loader'
require 'prawn/svg/color'
require 'prawn/svg/attributes'
require 'prawn/svg/elements'
require 'prawn/svg/extension'
require 'prawn/svg/interface'
require 'prawn/svg/font'
require 'prawn/svg/document'

module Prawn
  Svg = SVG # backwards compatibility
end

Prawn::Document.extensions << Prawn::SVG::Extension
