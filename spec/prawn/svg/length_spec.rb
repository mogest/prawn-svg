require 'spec_helper'

describe Prawn::SVG::Length do
  describe '.parse' do
    it 'parses a length' do
      expect(described_class.parse('1.23em')).to eq(described_class.new(1.23, :em))
    end

    it 'parses a length with a positive sign' do
      expect(described_class.parse('+1.23em')).to eq(described_class.new(1.23, :em))
    end

    it 'parses a length with a negative sign' do
      expect(described_class.parse('-1.23em')).to eq(described_class.new(-1.23, :em))
    end

    it 'parses a length with the unit in caps' do
      expect(described_class.parse('1.23EM')).to eq(described_class.new(1.23, :em))
    end

    it 'parses a length with no decimal points' do
      expect(described_class.parse('1em')).to eq(described_class.new(1, :em))
    end

    it 'parses a length with no unit' do
      expect(described_class.parse('1.23')).to eq(described_class.new(1.23, nil))
    end

    it 'allows numbers without a leading zero' do
      expect(described_class.parse('.23em')).to eq(described_class.new(0.23, :em))
    end

    it 'does not allow numbers with a trailing dot' do
      expect(described_class.parse('1.em')).to be nil
    end

    it 'does not allow units it does not recognise' do
      expect(described_class.parse('1.23foo')).to be nil
    end

    context 'when positive_only is true' do
      it 'does not allow negative numbers' do
        expect(described_class.parse('-1.23em', positive_only: true)).to be nil
      end

      it 'does allow zero' do
        expect(described_class.parse('0em', positive_only: true)).to eq(described_class.new(0, :em))
      end

      it 'does allow positive numbers' do
        expect(described_class.parse('1.23em', positive_only: true)).to eq(described_class.new(1.23, :em))
      end
    end
  end

  describe '#to_pixels' do
    it 'converts a em-unit length to pixels' do
      expect(described_class.new(2.5, :em).to_pixels(nil, 12)).to eq(12 * 2.5)
    end

    it 'converts a rem-unit length to pixels' do
      expect(described_class.new(2.5, :rem).to_pixels(nil, 12)).to eq(16 * 2.5)
    end

    it 'converts a ex-unit length to pixels' do
      expect(described_class.new(2.5, :ex).to_pixels(nil, 12)).to eq(6 * 2.5)
    end

    it 'converts a pc-unit length to pixels' do
      expect(described_class.new(2.5, :pc).to_pixels(nil, 12)).to eq(37.5)
    end

    it 'converts a in-unit length to pixels' do
      expect(described_class.new(2.5, :in).to_pixels(nil, 12)).to eq(180)
    end

    it 'converts a cm-unit length to pixels' do
      expect(described_class.new(2.5, :cm).to_pixels(nil, 12)).to be_within(0.001).of(70.866)
    end

    it 'converts a mm-unit length to pixels' do
      expect(described_class.new(2.5, :mm).to_pixels(nil, 12)).to be_within(0.001).of(7.087)
    end

    it 'returns the value for an unknown unit' do
      expect(described_class.new(2.5, nil).to_pixels(nil, 12)).to eq(2.5)
    end
  end
end
