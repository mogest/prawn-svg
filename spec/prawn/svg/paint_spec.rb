require 'spec_helper'

RSpec.describe Prawn::SVG::Paint do
  let(:red) { Prawn::SVG::Color::RGB.new('ff0000') }

  describe '.parse' do
    it 'parses a color' do
      expect(described_class.parse('red')).to eq(described_class.new(red, nil))
    end

    it 'parses an rgb color with an icc color, ignoring the icc color' do
      expect(described_class.parse('rgb(255, 0, 0) icc-color(1)')).to eq(described_class.new(red, nil))
    end

    it 'parses a URL' do
      expect(described_class.parse('url(#foo)')).to eq(described_class.new(:none, '#foo'))
    end

    it 'parses a keyword' do
      expect(described_class.parse('NONE')).to eq(described_class.new(:none, nil))
      expect(described_class.parse('currentColor')).to eq(described_class.new(:currentcolor, nil))
    end

    it 'parses a URL with a fallback keyword' do
      expect(described_class.parse('url(#foo) none')).to eq(described_class.new(:none, '#foo'))
    end

    it 'parses a URL with a fallback color' do
      expect(described_class.parse('url(#foo) red')).to eq(described_class.new(red, '#foo'))
    end

    it 'parses a URL with a fallback color and an icc color, ignoring the icc color' do
      expect(described_class.parse('url(#foo) red icc-color(1)')).to eq(described_class.new(red, '#foo'))
    end

    it 'returns nil if the value is unrecognised' do
      expect(described_class.parse('foo')).to be_nil
    end

    it 'returns nil if the url has multiple arguments' do
      expect(described_class.parse('url(#foo, bar)')).to be_nil
    end
  end

  describe '#none?' do
    it 'returns true if the color is none' do
      expect(described_class.new(:none, nil).none?).to be(true)
    end

    it 'returns true if the color is none and the URL is unresolved' do
      paint = described_class.new(:none, '#foo')
      paint.instance_variable_set(:@unresolved_url, true)
      expect(paint.none?).to be(true)
    end

    it 'returns false if the color is not none' do
      expect(described_class.new(Prawn::SVG::Color::RGB.new('ff0000'), nil).none?).to be(false)
    end
  end

  describe '#resolve' do
    it 'returns the current color if the color is currentcolor' do
      current_color = double
      paint = described_class.new(:currentcolor, nil)
      expect(paint.resolve(nil, current_color, :rgb)).to eq current_color
    end

    it 'returns the nil if the color is none' do
      current_color = double
      paint = described_class.new(:none, nil)
      expect(paint.resolve(nil, current_color, :rgb)).to be nil
    end

    it 'returns the gradient if the URL is resolvable' do
      gradient = double
      paint = described_class.new(:none, '#foo')
      expect(paint.resolve({ 'foo' => gradient }, nil, :rgb)).to eq(gradient)
    end

    it 'falls back to the color if the URL is unresolvable' do
      paint = described_class.new(red, '#foo')
      expect(paint.resolve(nil, nil, :rgb)).to eq red
      expect(paint.resolve({}, nil, :rgb)).to eq red
    end

    it 'returns the color if the color is not currentcolor or none' do
      paint = described_class.new(red, nil)
      expect(paint.resolve(nil, nil, :rgb)).to eq red
    end

    it 'converts the color to CMYK if the color mode is CMYK' do
      paint = described_class.new(red, nil)
      expect(paint.resolve(nil, nil, :cmyk)).to eq Prawn::SVG::Color::CMYK.new([0, 100, 100, 0])
    end
  end
end
