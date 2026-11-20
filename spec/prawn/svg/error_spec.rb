require "#{File.dirname(__FILE__)}/../../spec_helper"

describe Prawn::SVG::Error do
  it 'is the base of the errors prawn-svg raises' do
    [Prawn::SVG::IssueError, Prawn::SVG::InvalidSVGData, Prawn::SVG::WorkLimitExceeded,
     Prawn::SVG::Requests::Error].each do |klass|
      expect(klass.ancestors).to include described_class
    end
  end

  it 'keeps the old Document error names' do
    expect(Prawn::SVG::Document::Error).to eq described_class
    expect(Prawn::SVG::Document::InvalidSVGData).to eq Prawn::SVG::InvalidSVGData
  end
end
