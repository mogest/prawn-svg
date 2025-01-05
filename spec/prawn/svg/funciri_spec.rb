require 'spec_helper'

describe Prawn::SVG::FuncIRI do
  describe '.parse' do
    it 'parses a URL' do
      expect(described_class.parse('url(#foo)')).to eq(described_class.new('#foo'))
    end

    it 'parses a URL with whitespace' do
      expect(described_class.parse('url( #foo )')).to eq(described_class.new('#foo'))
    end

    it 'parses a URL with quotes' do
      expect(described_class.parse('url("#foo")')).to eq(described_class.new('#foo'))
    end

    it 'parses a URL with quotes and whitespace' do
      expect(described_class.parse('url( "#foo" )')).to eq(described_class.new('#foo'))
    end

    it 'parses a URL with double quotes' do
      expect(described_class.parse('url("#foo")')).to eq(described_class.new('#foo'))
    end

    it 'parses a URL with double quotes and whitespace' do
      expect(described_class.parse('url( "#foo" )')).to eq(described_class.new('#foo'))
    end

    it 'parses a URL with single quotes' do
      expect(described_class.parse("url('#foo')")).to eq(described_class.new('#foo'))
    end

    it 'parses a URL with single quotes and whitespace' do
      expect(described_class.parse("url( '#foo' )")).to eq(described_class.new('#foo'))
    end

    it 'parses a URL with both single and double quotes' do
      expect(described_class.parse('url("#foo")')).to eq(described_class.new('#foo'))
    end

    it 'parses a URL with both single and double quotes and whitespace' do
      expect(described_class.parse('url( "#foo" )')).to eq(described_class.new('#foo'))
    end

    it 'parses a URL with both single and double quotes and whitespace' do
      expect(described_class.parse('url( "#foo" )')).to eq(described_class.new('#foo'))
    end

    it 'parses a URL with escaped quotes' do
      expect(described_class.parse('url("\\#foo")')).to eq(described_class.new('#foo'))
    end

    it 'ignores a non-URL value' do
      expect(described_class.parse('foo')).to be_nil
      expect(described_class.parse('foo(1)')).to be_nil
      expect(described_class.parse('url(1, 2)')).to be_nil
    end
  end
end
