require 'spec_helper'

describe Prawn::SVG::Percentage do
  describe '.parse' do
    it 'parses a percentage' do
      expect(described_class.parse('1.23%')).to eq(described_class.new(1.23))
    end

    it 'parses a percentage with a positive sign' do
      expect(described_class.parse('+1.23%')).to eq(described_class.new(1.23))
    end

    it 'parses a percentage with a negative sign' do
      expect(described_class.parse('-1.23%')).to eq(described_class.new(-1.23))
    end

    it 'parses a percentage with no decimal points' do
      expect(described_class.parse('1%')).to eq(described_class.new(1))
    end

    it 'does not parse a percentage with no number' do
      expect(described_class.parse('%')).to be nil
    end

    it 'does not parse a percentage with a trailing dot' do
      expect(described_class.parse('1.%')).to be nil
    end

    it 'requires that the percentage sign is specified' do
      expect(described_class.parse('1.23')).to be nil
    end

    context 'when positive_only is true' do
      it 'does not allow negative numbers' do
        expect(described_class.parse('-1.23%', positive_only: true)).to be nil
      end

      it 'does allow zero' do
        expect(described_class.parse('0%', positive_only: true)).to eq(described_class.new(0))
      end

      it 'does allow positive numbers' do
        expect(described_class.parse('1.23%', positive_only: true)).to eq(described_class.new(1.23))
      end
    end
  end

  describe '#to_factor' do
    it 'converts a percentage to a factor' do
      expect(described_class.new(2.5).to_factor).to eq(0.025)
    end
  end

  describe '#to_pixels' do
    it 'converts a percentage to pixels' do
      expect(described_class.new(2.5).to_pixels(100, nil)).to eq(2.5)
      expect(described_class.new(2.5).to_pixels(200, nil)).to eq(5)
    end
  end
end
