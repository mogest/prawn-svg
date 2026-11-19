require "#{File.dirname(__FILE__)}/../../spec_helper"

describe Prawn::SVG::Error do
  it 'is the base of the errors prawn-svg raises' do
    [Prawn::SVG::IssueError, Prawn::SVG::Document::InvalidSVGData, Prawn::SVG::Document::WorkLimitExceeded,
     Prawn::SVG::UrlLoader::Error].each do |klass|
      expect(klass.ancestors).to include described_class
    end
  end
end
