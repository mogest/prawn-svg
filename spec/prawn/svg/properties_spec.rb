require 'spec_helper'

RSpec.describe Prawn::SVG::Properties do
  subject { Prawn::SVG::Properties.new }

  describe '#load_default_stylesheet' do
    it 'loads in the defaults and returns self' do
      expect(subject.load_default_stylesheet).to eq subject
      expect(subject.font_family).to eq 'sans-serif'
    end
  end

  describe '#set' do
    it 'sets a property' do
      result = subject.set('color', 'red')
      expect(result).to be
      expect(subject.color).to eq Prawn::SVG::Color::RGB.new('ff0000')
    end

    it 'handles property names that are not lower case' do
      result = subject.set('COLor', 'red')
      expect(result).to be
      expect(subject.color).to eq Prawn::SVG::Color::RGB.new('ff0000')
    end

    it 'right-cases and strips keywords' do
      subject.set('stroke-linecap', ' Round ')
      expect(subject.stroke_linecap).to eq 'round'
    end

    it 'ignores invalid values, retaining any previously set value' do
      subject.set('display', 'invalid')
      expect(subject.display).to be nil
      subject.set('display', 'none')
      expect(subject.display).to eq 'none'
      subject.set('display', 'invalid')
      expect(subject.display).to eq 'none'
    end
  end

  describe '#load_hash' do
    it 'uses #set to load in a hash of properties' do
      subject.load_hash('stroke' => 'blue', 'fill' => 'green', 'stroke-linecap' => 'Round')
      expect(subject.stroke).to eq Prawn::SVG::Paint.new(Prawn::SVG::Color::RGB.new('0000ff'))
      expect(subject.fill).to eq Prawn::SVG::Paint.new(Prawn::SVG::Color::RGB.new('008000'))
      expect(subject.stroke_linecap).to eq 'round'
    end
  end

  describe '#compute_properties' do
    let(:other) { Prawn::SVG::Properties.new }

    it 'auto-inherits inheritable properties when the property is not supplied' do
      subject.set('color', 'green')
      subject.compute_properties(other)
      expect(subject.color).to eq Prawn::SVG::Color::RGB.new('008000')
    end

    it "doesn't auto-inherit non-inheritable properties" do
      subject.set('display', 'none')
      subject.compute_properties(other)
      expect(subject.display).to eq 'inline'
    end

    it 'inherits non-inheritable properties when specifically asked to' do
      subject.set('display', 'none')
      other.set('display', 'inherit')
      subject.compute_properties(other)
      expect(subject.display).to eq 'none'
    end

    it 'uses the new property value' do
      subject.set('color', 'green')
      other.set('color', 'red')
      subject.compute_properties(other)
      expect(subject.color).to eq Prawn::SVG::Color::RGB.new('ff0000')
    end
  end

  describe '#numeric_font_size' do
    def calculate
      properties = Prawn::SVG::Properties.new
      properties.compute_properties(subject)
      properties.numeric_font_size
    end

    cases =
      {
        Prawn::SVG::Length.parse('18.5pt') => 18.5,
        Prawn::SVG::Percentage.new(120)    => 19.2,
        19.5                               => 19.5,
        'larger'                           => 20,
        'smaller'                          => 12,
        nil                                => 16,
        'inherit'                          => 16,
        'x-large'                          => 24
      }

    cases.each do |font_size, expected|
      context "when the font size is #{font_size.inspect}" do
        before { subject.font_size = font_size }

        it 'returns the correct number' do
          expect(calculate).to eq expected
        end
      end
    end

    context 'with a font-size of 1.2em, under a parent with a font size of x-large' do
      it 'returns 24 * 1.2' do
        a = Prawn::SVG::Properties.new
        a.set('font-size', 'x-large')

        b = Prawn::SVG::Properties.new
        b.set('font-size', '1.2em')

        properties = Prawn::SVG::Properties.new
        properties.compute_properties(a)
        properties.compute_properties(b)

        expect(properties.numeric_font_size.round(1)).to eq 28.8
      end
    end
  end
end
