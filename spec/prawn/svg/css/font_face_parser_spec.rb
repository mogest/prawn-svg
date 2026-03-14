require 'spec_helper'

RSpec.describe Prawn::SVG::CSS::FontFaceParser do
  describe '.parse_src' do
    it 'parses a simple url() source' do
      result = described_class.parse_src('url("font.ttf")')
      expect(result).to eq([{ type: :url, url: 'font.ttf', format: nil }])
    end

    it 'parses a url() with format()' do
      result = described_class.parse_src('url("font.ttf") format("truetype")')
      expect(result).to eq([{ type: :url, url: 'font.ttf', format: 'truetype' }])
    end

    it 'parses a local() source' do
      result = described_class.parse_src('local("Helvetica")')
      expect(result).to eq([{ type: :local, name: 'Helvetica' }])
    end

    it 'parses multiple comma-separated sources' do
      result = described_class.parse_src('local("Helvetica"), url("font.ttf") format("truetype"), url("fallback.otf")')
      expect(result).to eq([
                             { type: :local, name: 'Helvetica' },
                             { type: :url, url: 'font.ttf', format: 'truetype' },
                             { type: :url, url: 'fallback.otf', format: nil }
                           ])
    end

    it 'handles single-quoted strings' do
      result = described_class.parse_src("url('font.ttf') format('truetype')")
      expect(result).to eq([{ type: :url, url: 'font.ttf', format: 'truetype' }])
    end

    it 'handles unquoted url values' do
      result = described_class.parse_src('url(font.ttf)')
      expect(result).to eq([{ type: :url, url: 'font.ttf', format: nil }])
    end

    it 'handles URLs with commas inside quotes' do
      result = described_class.parse_src('url("font,name.ttf"), url("other.ttf")')
      expect(result).to eq([
                             { type: :url, url: 'font,name.ttf', format: nil },
                             { type: :url, url: 'other.ttf', format: nil }
                           ])
    end

    it 'handles empty src' do
      expect(described_class.parse_src('')).to eq([])
    end

    it 'ignores entries with unknown function types' do
      result = described_class.parse_src('something("test"), url("font.ttf")')
      expect(result).to eq([{ type: :url, url: 'font.ttf', format: nil }])
    end

    it 'parses data URLs' do
      data_url = 'data:font/ttf;base64,AAEAAAALAI=='
      result = described_class.parse_src("url(\"#{data_url}\")")
      expect(result).to eq([{ type: :url, url: data_url, format: nil }])
    end

    it 'parses a complex multi-format chain' do
      src = 'local("Font"), url("font.woff2") format("woff2"), url("font.ttf") format("truetype")'
      result = described_class.parse_src(src)
      expect(result).to eq([
                             { type: :local, name: 'Font' },
                             { type: :url, url: 'font.woff2', format: 'woff2' },
                             { type: :url, url: 'font.ttf', format: 'truetype' }
                           ])
    end
  end
end
