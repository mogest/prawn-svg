require 'spec_helper'

RSpec.describe Prawn::SVG::TTF do
  let(:filename) { "#{File.dirname(__FILE__)}/../../sample_ttf/OpenSans-SemiboldItalic.ttf" }

  subject { Prawn::SVG::TTF.new(filename) }

  it "gets the English family and subfamily from the font file" do
    expect(subject.family).to eq 'Open Sans'
    expect(subject.subfamily).to eq 'Semibold Italic'
  end
end
