require 'spec_helper'

RSpec.describe Prawn::SVG::Elements::Line do
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], {width: 800, height: 600}) }

  subject do
    Prawn::SVG::Elements::Line.new(document, document.root, [], fake_state)
  end

  context "with attributes specified" do
    let(:svg) { '<line x1="5" y1="10" x2="15" y2="20" />' }

    it "renders the line" do
      subject.process
      expect(subject.base_calls).to eq [
        ["fill", [], [
          ["move_to", [[5.0, 590.0]], []],
          ["line_to", [[15.0, 580.0]], []]]
        ]
      ]
    end
  end

  context "with no attributes specified" do
    let(:svg) { '<line />' }

    it "draws a line from 0,0 to 0,0" do
      subject.process
      expect(subject.base_calls).to eq [
        ["fill", [], [
          ["move_to", [[0, 600]], []],
          ["line_to", [[0, 600]], []]]
        ]
      ]
    end
  end
end
