module Prawn::SVG
  Error = Class.new(StandardError)

  module Requests
    Error = Class.new(Prawn::SVG::Error)
  end
end
