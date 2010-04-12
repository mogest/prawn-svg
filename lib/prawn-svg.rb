require 'prawn'
require 'prawn/svg/extension'
require 'prawn/svg/interface'
require 'prawn/svg/parser'
require 'prawn/svg/parser/path'

Prawn::Document.extensions << Prawn::Svg::Extension
