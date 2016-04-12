module Prawn::SVG::Attributes
end

%w(transform opacity clip_path stroke).each do |name|
  require "prawn/svg/attributes/#{name}"
end
