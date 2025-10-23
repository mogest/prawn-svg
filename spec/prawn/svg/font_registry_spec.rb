require 'spec_helper'

RSpec.describe Prawn::SVG::FontRegistry do
  describe '#load' do
    let(:pdf) { Prawn::Document.new }
    let(:font_registry) { Prawn::SVG::FontRegistry.new(pdf.font_families) }

    it 'matches a built in font' do
      expect(font_registry.load("blah, 'courier', nothing").name).to eq('Courier')
    end

    it 'matches a default font' do
      expect(font_registry.load('serif').name).to be_truthy
      expect(font_registry.load('blah, serif').name).to be_truthy
      expect(font_registry.load('blah, serif , test').name).to eq('Times-Roman')
    end

    it 'allows generic font family to be remapped in font registry' do
      pdf = Prawn::Document.new
      pdf.font_families.update('serif' => { normal: 'Courier' })
      registry = Prawn::SVG::FontRegistry.new(pdf.font_families)

      font = registry.load('serif')
      expect(font.name).to eq('serif')
    end

    if Prawn::SVG::FontRegistry.new({}).installed_fonts['Verdana']
      it 'matches a font installed on the system' do
        expect(font_registry.load('verdana, sans-serif').name).to eq('Verdana')
        expect(font_registry.load('VERDANA, sans-serif').name).to eq('Verdana')
        expect(font_registry.load('something, "Times New Roman", serif').name).to be_truthy
        expect(font_registry.load('something, Times New Roman, serif').name).to eq('Times New Roman')
      end
    else
      it "not running font test because we couldn't find Verdana installed on the system"
    end

    it "returns nil if it can't find any such font" do
      expect(font_registry.load('blah, thing')).to be_nil
      expect(font_registry.load('')).to be_nil
    end

    it 'handles CSS font weights' do
      font = font_registry.load('courier', '700')
      expect(font.weight).to eq(:bold)
    end

    it 'normalizes multiple spaces in font names' do
      font = font_registry.load('courier   , times')
      expect(font.name).to eq('Courier')
    end

    it 'falls back when requested weight is unavailable' do
      font = font_registry.load('courier', :black)
      expect(font.name).to eq('Courier')
    end

    it 'handles font weight and style parameters' do
      font = font_registry.load('courier', :bold, :italic)
      expect(font.weight).to eq(:bold)
      expect(font.style).to eq(:italic)
    end

    it 'converts CSS numeric weights to symbols' do
      expect(font_registry.load('courier', '400').weight).to eq(:normal)
      expect(font_registry.load('courier', '700').weight).to eq(:bold)
    end

    it 'falls back from style when unavailable' do
      font = font_registry.load('courier', :normal, :italic)
      expect(font.name).to eq('Courier')
    end

    it 'processes comma-separated font families' do
      font = font_registry.load('nonexistent, courier, times')
      expect(font.name).to eq('Courier')
    end

    it 'handles quoted font names with commas' do
      font = font_registry.load('"font, with comma", courier')
      expect(font.name).to eq('Courier')
    end

    describe 'weight fallbacks' do
      before do
        # Mock a font family with only normal and bold available
        allow(font_registry).to receive(:installed_fonts).and_return({
          'TestFont' => { normal: 'test.ttf', bold: 'test-bold.ttf' }
        })
        allow(font_registry).to receive(:correctly_cased_font_name).and_return('TestFont')
      end

      it 'falls back from light to normal' do
        font = font_registry.load('TestFont', :light)
        expect(font.weight).to eq(:normal)
      end

      it 'falls back from semibold to bold to normal' do
        font = font_registry.load('TestFont', :semibold)
        expect(font.weight).to eq(:bold)
      end

      it 'falls back from extrabold to bold' do
        font = font_registry.load('TestFont', :extrabold)
        expect(font.weight).to eq(:bold)
      end

      it 'falls back from black to bold' do
        font = font_registry.load('TestFont', :black)
        expect(font.weight).to eq(:bold)
      end

      context 'when only normal weight is available' do
        before do
          allow(font_registry).to receive(:installed_fonts).and_return({
            'TestFont' => { normal: 'test.ttf' }
          })
        end

        it 'falls back from bold to normal' do
          font = font_registry.load('TestFont', :bold)
          expect(font.weight).to eq(:normal)
        end

        it 'falls back through the entire chain to normal' do
          font = font_registry.load('TestFont', :black)
          expect(font.weight).to eq(:normal)
        end
      end

      context 'when all weights are available' do
        before do
          allow(font_registry).to receive(:installed_fonts).and_return({
            'TestFont' => {
              light:     'test-light.ttf',
              normal:    'test.ttf',
              semibold:  'test-semibold.ttf',
              bold:      'test-bold.ttf',
              extrabold: 'test-extrabold.ttf',
              black:     'test-black.ttf'
            }
          })
        end

        it 'returns exact weight matches without fallback' do
          expect(font_registry.load('TestFont', :light).weight).to eq(:light)
          expect(font_registry.load('TestFont', :semibold).weight).to eq(:semibold)
          expect(font_registry.load('TestFont', :extrabold).weight).to eq(:extrabold)
          expect(font_registry.load('TestFont', :black).weight).to eq(:black)
        end
      end
    end
  end

  describe '#installed_fonts' do
    let(:ttf)  { instance_double(Prawn::SVG::TTF, family: 'Awesome Font', subfamily: 'Italic') }
    let(:ttf2) { instance_double(Prawn::SVG::TTF, family: 'Awesome Font', subfamily: 'Regular') }
    before { Prawn::SVG::FontRegistry.external_font_families.clear }

    let(:pdf) do
      doc = Prawn::Document.new
      doc.font_families.update({
        'Awesome Font' => { italic: 'second.ttf', normal: 'file.ttf' }
      })
      doc
    end

    let(:font_registry) { Prawn::SVG::FontRegistry.new(pdf.font_families) }

    it 'does not override existing entries in pdf when loading external fonts' do
      expect(Prawn::SVG::FontRegistry).to receive(:font_path).and_return(['x'])
      expect(Dir).to receive(:[]).with('x/**/*').and_return(['file.ttf', 'second.ttf'])
      expect(Prawn::SVG::TTF).to receive(:new).with('file.ttf').and_return(ttf)
      expect(Prawn::SVG::TTF).to receive(:new).with('second.ttf').and_return(ttf2)
      expect(File).to receive(:file?).at_least(:once).and_return(true)

      Prawn::SVG::FontRegistry.load_external_fonts
      font_registry.installed_fonts

      existing_font = font_registry.installed_fonts['Awesome Font']
      expect(existing_font).to eq(italic: 'second.ttf', normal: 'file.ttf')
    end
  end

  describe '::load_external_fonts' do
    let(:ttf)  { instance_double(Prawn::SVG::TTF, family: 'Awesome Font', subfamily: 'Italic') }
    let(:ttf2) { instance_double(Prawn::SVG::TTF, family: 'Awesome Font', subfamily: 'Regular') }

    before { Prawn::SVG::FontRegistry.external_font_families.clear }

    it 'scans the font path and loads in some fonts' do
      expect(Prawn::SVG::FontRegistry).to receive(:font_path).and_return(['x'])
      expect(Dir).to receive(:[]).with('x/**/*').and_return(['file.ttf', 'second.ttf'])
      expect(Prawn::SVG::TTF).to receive(:new).with('file.ttf').and_return(ttf)
      expect(Prawn::SVG::TTF).to receive(:new).with('second.ttf').and_return(ttf2)
      expect(File).to receive(:file?).at_least(:once).and_return(true)

      Prawn::SVG::FontRegistry.load_external_fonts

      result = Prawn::SVG::FontRegistry.external_font_families
      expect(result).to eq('Awesome Font' => { italic: 'file.ttf', normal: 'second.ttf' })
    end
  end
end
