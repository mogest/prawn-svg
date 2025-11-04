require 'spec_helper'

RSpec.describe Prawn::SVG::FontMetrics do
  let(:pdf) { Prawn::Document.new }

  describe '.underline_metrics' do
    it 'does not return the same values for different font sizes' do
      underline_10 = described_class.underline_metrics(pdf, 10)
      underline_20 = described_class.underline_metrics(pdf, 20)

      expect(underline_10).to_not eq(underline_20)
    end
  end
end
