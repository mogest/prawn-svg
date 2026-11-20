module Prawn::SVG
  Error = Class.new(StandardError)
  InvalidSVGData = Class.new(Error)
  WorkLimitExceeded = Class.new(Error)

  module Requests
    Error = Class.new(Prawn::SVG::Error)
  end
end
