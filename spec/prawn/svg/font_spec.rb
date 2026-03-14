require "#{File.dirname(__FILE__)}/../../spec_helper"

describe Prawn::SVG::Font do
  describe '#initialize' do
    it 'sets name, weight, and style' do
      font = Prawn::SVG::Font.new('Arial', :bold, :italic)
      expect(font.name).to eq('Arial')
      expect(font.weight).to eq(:bold)
      expect(font.style).to eq(:italic)
    end

    it 'sets stretch when provided' do
      font = Prawn::SVG::Font.new('Arial', :bold, :italic, :condensed)
      expect(font.stretch).to eq(:condensed)
    end

    it 'defaults stretch to nil' do
      font = Prawn::SVG::Font.new('Arial', :bold, :italic)
      expect(font.stretch).to be_nil
    end
  end

  describe '#subfamily' do
    it 'returns :normal when weight and style are both normal' do
      font = Prawn::SVG::Font.new('Arial', :normal, nil)
      expect(font.subfamily).to eq(:normal)
    end

    it 'returns style when weight is normal and style is present' do
      font = Prawn::SVG::Font.new('Arial', :normal, :italic)
      expect(font.subfamily).to eq(:italic)
    end

    it 'returns weight when only weight is present' do
      font = Prawn::SVG::Font.new('Arial', :bold, nil)
      expect(font.subfamily).to eq(:bold)
    end

    it 'returns combined weight and style when both are present' do
      font = Prawn::SVG::Font.new('Arial', :bold, :italic)
      expect(font.subfamily).to eq(:bold_italic)
    end

    it 'returns :normal when both weight and style are nil' do
      font = Prawn::SVG::Font.new('Arial', nil, nil)
      expect(font.subfamily).to eq(:normal)
    end

    context 'with stretch' do
      it 'returns stretch alone when weight is normal and no style' do
        font = Prawn::SVG::Font.new('Arial', :normal, nil, :condensed)
        expect(font.subfamily).to eq(:condensed)
      end

      it 'returns stretch with style when weight is normal' do
        font = Prawn::SVG::Font.new('Arial', :normal, :italic, :condensed)
        expect(font.subfamily).to eq(:condensed_italic)
      end

      it 'returns stretch with weight' do
        font = Prawn::SVG::Font.new('Arial', :bold, nil, :condensed)
        expect(font.subfamily).to eq(:condensed_bold)
      end

      it 'returns stretch with weight and style' do
        font = Prawn::SVG::Font.new('Arial', :bold, :italic, :condensed)
        expect(font.subfamily).to eq(:condensed_bold_italic)
      end

      it 'ignores :normal stretch' do
        font = Prawn::SVG::Font.new('Arial', :bold, nil, :normal)
        expect(font.subfamily).to eq(:bold)
      end
    end
  end
end
