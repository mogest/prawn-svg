module Prawn::SVG::Attributes
end

%w[transform opacity clip_path mask stroke space].each do |name|
  require "prawn/svg/attributes/#{name}"
end
