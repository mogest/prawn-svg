require File.dirname(__FILE__) + '/../../../spec_helper'

describe Prawn::Svg::Parser::Text do
  describe "xml:space preserve" do
    let(:svg)      { %(<text#{attributes}>some\n\t  text</text>) }
    let(:document) { Prawn::Svg::Document.new(svg, [800, 600], {}) }
    let(:element)  { Prawn::Svg::Element.new(document, document.root, [], {}) }
    let(:parser)   { Prawn::Svg::Parser::Text.new }

    context "when xml:space is preserve" do
      let(:attributes) { ' xml:space="preserve"' }

      it "converts newlines and tabs to spaces, and preserves spaces" do
        parser.parse(element)

        expect(element.calls).to eq [
          ["draw_text", ["some    text", {:style=>nil, :at=>[0.0, 600.0]}], []]
        ]
      end
    end

    context "when xml:space is unspecified" do
      let(:attributes) { '' }

      it "strips space" do
        parser.parse(element)

        expect(element.calls).to eq [
          ["draw_text", ["some text", {:style=>nil, :at=>[0.0, 600.0]}], []]
        ]
      end
    end
  end
end
