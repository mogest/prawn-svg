require 'spec_helper'

describe Prawn::SVG::AttributeValue do
  def self.check(type, valid:, invalid:)
    describe type.inspect do
      valid.each do |value|
        it("accepts #{value.inspect}") { expect(described_class.valid?(type, value)).to be_truthy }
      end

      invalid.each do |value|
        it("rejects #{value.inspect}") { expect(described_class.valid?(type, value)).to be_falsey }
      end
    end
  end

  check :length, valid: ['10', ' 1.5px ', '-2em', '50%', '1e3', '.5'], invalid: ['', '2no', 'calc(1px)', '10vw', 'auto']
  check :number_or_percentage, valid: ['0.5', '50%', '1e-1'], invalid: ['5px', '0x1A', '5.']
  check :length_list, valid: ['10 20', '10,20%', ''], invalid: ['10 x']
  check :number_list, valid: ['10 -20.5', '45'], invalid: ['45deg']
  check :view_box, valid: ['0 0 100 100', '-10,-10,20,20', '0 0 0 0', '0 0 -1 10'], invalid: ['0 0 100', '0 0 100px 100']
  check :preserve_aspect_ratio, valid: ['none', 'xMidYMid', 'defer xMinYMax slice'], invalid: ['xmidymid', 'xMidYMid fill', 'meet']
  check :orient, valid: ['auto', '45', '1rad', '100grad'], invalid: ['up', 'auto-start-reverse', '0.5turn']
  check %w[pad reflect], valid: ['pad', 'reflect'], invalid: ['Pad', ' reflect ', 'repeat']
end
