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
  end
end
