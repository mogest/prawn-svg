require 'spec_helper'

describe Prawn::SVG::Number do
  describe '.parse' do
    it 'parses a number' do
      expect(described_class.parse('-1.5e2')).to eq(-150.0)
      expect(described_class.parse('.5')).to eq 0.5
    end

    it 'rejects a decimal point without digits after it' do
      expect(described_class.parse('2.')).to be_nil
    end

    it 'rejects numbers outside the single-precision range' do
      expect(described_class.parse('3.4e38')).to eq 3.4e38
      expect(described_class.parse('3.5e38')).to be_nil
      expect(described_class.parse('-1e999')).to be_nil
      expect(described_class.parse("1#{'0' * 400}")).to be_nil
    end

    it 'rounds numbers too small for single precision to zero' do
      expect(described_class.parse('1e-38')).to eq 0.0
      expect(described_class.parse('-1e-320')).to eq 0.0
    end

    it 'rejects things that are not numbers' do
      expect(described_class.parse('abc')).to be_nil
      expect(described_class.parse('')).to be_nil
    end
  end
end
