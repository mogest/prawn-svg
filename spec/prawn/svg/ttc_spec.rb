require 'spec_helper'

RSpec.describe Prawn::SVG::TTC do
  subject { Prawn::SVG::TTC.new(filename) }

  context 'with a TrueType Collection font' do
    let(:filename) { "#{File.dirname(__FILE__)}/../../sample_ttf/TestFamily.ttc" }

    it 'extracts family, subfamily, and index for each font in the collection' do
      expect(subject.fonts.length).to eq 2
      expect(subject.fonts[0]).to eq(family: 'Test Family', subfamily: 'Regular', index: 0)
      expect(subject.fonts[1]).to eq(family: 'Test Family', subfamily: 'Bold', index: 1)
    end
  end

  context "with a file that isn't a TTC" do
    let(:filename) { "#{File.dirname(__FILE__)}/../../sample_ttf/OpenSans-SemiboldItalic.ttf" }

    it 'returns no fonts' do
      expect(subject.fonts).to be_empty
    end
  end

  context "with a file that doesn't exist" do
    let(:filename) { 'does_not_exist' }

    it 'returns no fonts' do
      expect(subject.fonts).to be_empty
    end
  end
end
