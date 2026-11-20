require 'spec_helper'

RSpec.describe Prawn::SVG::FontMetrics do
  let(:pdf) { Prawn::Document.new }

  describe '.underline_metrics' do
    it 'does not return the same values for different font sizes' do
      underline_10 = described_class.underline_metrics(pdf, 10)
      underline_20 = described_class.underline_metrics(pdf, 20)

      expect(underline_10).to_not eq(underline_20)
    end

    it 'uses the underline position from a TTF font' do
      pdf.font(File.expand_path('../../sample_ttf/OpenSans-SemiboldItalic.ttf', __dir__)) do
        offset, = described_class.underline_metrics(pdf, 20)
        expect(offset).to eq((-154.0 / 2048 * 20) - 0.5)
      end
    end

    it 'ignores a TTF underline position at or above the baseline' do
      pdf.font(File.expand_path('../../sample_ttf/OpenSans-SemiboldItalic.ttf', __dir__)) do
        allow(pdf.font.ttf.postscript).to receive(:underline_position).and_return(125)
        offset, = described_class.underline_metrics(pdf, 30)
        expect(offset).to eq(-0.12 * 30)
      end
    end
  end
  describe '.strikethrough_metrics' do
    it 'uses the strikeout position from a TTF font' do
      pdf.font(File.expand_path('../../sample_ttf/OpenSans-SemiboldItalic.ttf', __dir__)) do
        offset, = described_class.strikethrough_metrics(pdf, 20)
        expect(offset).to eq(pdf.font.ttf.os2.y_strikeout_position / 2048.0 * 20)
      end
    end

    it 'uses a default position for a built-in font' do
      offset, = described_class.strikethrough_metrics(pdf, 20)
      expect(offset).to eq(0.3 * 20)
    end
  end
end
