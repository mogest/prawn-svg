require File.dirname(__FILE__) + '/../../../spec_helper'

describe Prawn::SVG::Elements::Text do
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], {}) }
  let(:element)  { Prawn::SVG::Elements::Text.new(document, document.root, [], {}) }

  describe "xml:space preserve" do
    let(:svg) { %(<text#{attributes}>some\n\t  text</text>) }

    context "when xml:space is preserve" do
      let(:attributes) { ' xml:space="preserve"' }

      it "converts newlines and tabs to spaces, and preserves spaces" do
        element.process

        expect(element.calls).to eq [
          ["draw_text", ["some    text", {:style=>nil, :at=>[0.0, 150.0]}], []]
        ]
      end
    end

    context "when xml:space is unspecified" do
      let(:attributes) { '' }

      it "strips space" do
        element.process

        expect(element.calls).to eq [
          ["draw_text", ["some text", {:style=>nil, :at=>[0.0, 150.0]}], []]
        ]
      end
    end
  end

  describe "when text-anchor is specified" do
    let(:svg) { '<g text-anchor="middle" font-family="sans-serif" font-size="12"><text x="50" y="14">Text</text></g>' }

    it "should inherit text-anchor from parent element" do
      element.process
      expect(element.state[:text_anchor]).to eq 'middle'
    end
  end

  describe "letter-spacing" do
    let(:svg) { '<text letter-spacing="5">spaced</text>' }

    it "calls character_spacing with the requested size" do
      element.process

      expect(element.base_calls).to eq [
        ["end_path", [], [
          ["text_group", [], [
            ["character_spacing", [5.0], [
              ["draw_text", ["spaced", {:style=>nil, :at=>[0.0, 150.0]}], []]
            ]]
          ]]
        ]]
      ]
    end
  end
end
