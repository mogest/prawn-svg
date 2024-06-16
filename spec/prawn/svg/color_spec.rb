require "#{File.dirname(__FILE__)}/../../spec_helper"

describe Prawn::SVG::Color do
  describe '::css_color_to_prawn_color' do
    it 'converts #xxx to a hex value' do
      Prawn::SVG::Color.css_color_to_prawn_color('#9ab').should == '99aabb'
    end

    it 'converts #xxxxxx to a hex value' do
      Prawn::SVG::Color.css_color_to_prawn_color('#9ab123').should == '9ab123'
    end

    it 'converts an html colour name to a hex value' do
      Prawn::SVG::Color.css_color_to_prawn_color('White').should == 'ffffff'
    end

    it 'converts an rgb string to a hex value' do
      Prawn::SVG::Color.css_color_to_prawn_color('rgb(16, 32, 48)').should
      Prawn::SVG::Color.css_color_to_prawn_color('rgb(-5, 50%, 120%)').should == '007fff'
    end

    it 'converts a CMYK string to an array of numbers' do
      expect(Prawn::SVG::Color.css_color_to_prawn_color('device-cmyk(0, 0.32, 0.48, 1)')).to eq [0, 32, 48, 100]
      expect(Prawn::SVG::Color.css_color_to_prawn_color('device-cmyk(-5, 50%, 120%, -5%)')).to eq [0, 50, 100, 0]
    end

    it 'scans the string and finds the first colour it can parse' do
      Prawn::SVG::Color.css_color_to_prawn_color('function(#someurl, 0) nonexistent rgb( 3 ,4,5 ) white').should == '030405'
    end

    it 'ignores url()s' do
      expect(Prawn::SVG::Color.css_color_to_prawn_color('url(#someplace) red')).to eq 'ff0000'
    end

    it "returns black if the color doesn't exist" do
      expect(Prawn::SVG::Color.css_color_to_prawn_color('blurble')).to eq '000000'
    end

    it "returns nil if there's no fallback after a url()" do
      expect(Prawn::SVG::Color.css_color_to_prawn_color('url(#someplace)')).to be nil
    end
  end

  describe '::parse' do
    let(:gradients) { { 'flan' => flan_gradient, 'drob' => drob_gradient } }
    let(:flan_gradient) { double }
    let(:drob_gradient) { double }

    it 'returns a list of all colors parsed, ignoring impossible or non-existent colors' do
      results = Prawn::SVG::Color.parse('url(#nope) url(#flan) blurble green #123', gradients, :rgb)
      expect(results).to eq [
        flan_gradient,
        Prawn::SVG::Color::RGB.new('008000'),
        Prawn::SVG::Color::RGB.new('112233')
      ]
    end

    it "appends black to the list if there aren't any url() references" do
      results = Prawn::SVG::Color.parse('blurble green', gradients, :rgb)
      expect(results).to eq [
        Prawn::SVG::Color::RGB.new('008000'),
        Prawn::SVG::Color::RGB.new('000000')
      ]
    end

    it 'works in CMYK color mode' do
      results = Prawn::SVG::Color.parse('blurble green', gradients, :cmyk)
      expect(results).to eq [
        Prawn::SVG::Color::CMYK.new([100, 0, 100, 50]),
        Prawn::SVG::Color::CMYK.new([0, 0, 0, 100])
      ]
    end
  end
end
