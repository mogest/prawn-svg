require 'spec_helper'

describe Prawn::SVG::Angle do
  describe '.parse' do
    {
      '45' => 45, ' -45.5 ' => -45.5, '1e1' => 10, '90DEG' => 90, '100grad' => 90,
      '1rad' => 180 / Math::PI
    }.each do |value, degrees|
      it("parses #{value.inspect}") { expect(described_class.parse(value)).to eq degrees }
    end

    ['', 'deg', '45 deg', '45px', '0.25turn', 'auto'].each do |value|
      it("returns nil for #{value.inspect}") { expect(described_class.parse(value)).to be_nil }
    end
  end
end
