require 'spec_helper'

describe Prawn::SVG::Attributes::Font do
  class FontTestElement
    include Prawn::SVG::Attributes::Font

    attr_accessor :attributes, :warnings

    def initialize
      @state = {}
      @warnings = []
    end
  end

  let(:element) { FontTestElement.new }
  let(:document) { double(fallback_font_name: "Times-Roman") }

  before do
    allow(element).to receive(:document).and_return(document)
    element.attributes = {"font-family" => family}
  end

  describe "#parse_font_attributes_and_call" do
    context "with a specified existing font" do
      let(:family) { "Helvetica" }

      it "uses a font if it can find it" do
        expect(element).to receive(:add_call_and_enter).with("font", "Helvetica", style: :normal)
        element.parse_font_attributes_and_call
      end
    end

    context "with a specified non-existing font" do
      let(:family) { "Font That Doesn't Exist" }

      it "uses the fallback font if specified" do
        expect(element).to receive(:add_call_and_enter).with("font", "Times-Roman", style: :normal)
        element.parse_font_attributes_and_call
      end

      it "doesn't call the font method if there's no fallback font" do
        allow(document).to receive(:fallback_font_name).and_return(nil)
        expect(element).to_not receive(:add_call_and_enter)
        element.parse_font_attributes_and_call
        expect(element.warnings.length).to eq 1
      end
    end
  end
end
