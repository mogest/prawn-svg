require "#{File.dirname(__FILE__)}/../../spec_helper"

describe Prawn::SVG::Color do
  describe '::parse' do
    def parse(value)
      values = Prawn::SVG::CSS::ValuesParser.parse(value)
      Prawn::SVG::Color.parse(values[0])
    end

    it 'converts #xxx to an RGB color' do
      expect(parse('#9ab')).to eq Prawn::SVG::Color::RGB.new('99aabb')
    end

    it 'converts #xxxxxx to an RGB color' do
      expect(parse('#9ab123')).to eq Prawn::SVG::Color::RGB.new('9ab123')
    end

    it 'converts an html colour name to an RGB color' do
      expect(parse('White')).to eq Prawn::SVG::Color::RGB.new('ffffff')
    end

    it 'converts an rgb function to an RGB color' do
      expect(parse('rgb(16, 32, 48)')).to eq Prawn::SVG::Color::RGB.new('102030')
      expect(parse('rgb(-5, 50%, 120%)')).to eq Prawn::SVG::Color::RGB.new('007fff')
    end

    it 'converts a CMYK string to an array of numbers' do
      expect(parse('device-cmyk(0, 0.32, 0.48, 1.2)')).to eq Prawn::SVG::Color::CMYK.new([0, 32, 48, 100])
      expect(parse('device-cmyk(0, 50%, 120%, -5%)')).to eq Prawn::SVG::Color::CMYK.new([0, 50, 100, 0])
    end

    it "returns nil if the color doesn't exist" do
      expect(parse('blurble')).to be nil
    end

    it 'returns nil if the function has the wrong number of arguments' do
      expect(parse('rgb(-1, 0)')).to be nil
    end

    it "returns nil if it doesn't recognise the function" do
      expect(parse('hsl(0, 0, 0)')).to be nil
    end

    it 'converts an rgba function to an RGB color, discarding the alpha' do
      expect(parse('rgba(16, 32, 48, 0.5)')).to eq Prawn::SVG::Color::RGB.new('102030')
    end

    it 'returns nil if rgba has wrong number of arguments' do
      expect(parse('rgba(16, 32, 48)')).to be nil
    end
  end

  describe '::parse_with_alpha' do
    def parse_with_alpha(value)
      values = Prawn::SVG::CSS::ValuesParser.parse(value)
      Prawn::SVG::Color.parse_with_alpha(values[0])
    end

    it 'returns [color, alpha] for rgba values' do
      color, alpha = parse_with_alpha('rgba(255, 0, 0, 0.5)')
      expect(color).to eq Prawn::SVG::Color::RGB.new('ff0000')
      expect(alpha).to eq 0.5
    end

    it 'clamps alpha to 0.0..1.0' do
      _, alpha = parse_with_alpha('rgba(255, 0, 0, 1.5)')
      expect(alpha).to eq 1.0

      _, alpha = parse_with_alpha('rgba(255, 0, 0, -0.5)')
      expect(alpha).to eq 0.0
    end

    it 'returns [color, nil] for non-rgba values' do
      color, alpha = parse_with_alpha('rgb(255, 0, 0)')
      expect(color).to eq Prawn::SVG::Color::RGB.new('ff0000')
      expect(alpha).to be_nil
    end

    it 'returns [nil, nil] for invalid rgba' do
      color, alpha = parse_with_alpha('rgba(255, 0, 0)')
      expect(color).to be_nil
      expect(alpha).to be_nil
    end
  end
end
