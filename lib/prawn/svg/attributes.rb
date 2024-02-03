module Prawn::SVG::Attributes
end

%w(transform opacity clip_path stroke space mask).each do |name|
  require "prawn/svg/attributes/#{name}"
end
