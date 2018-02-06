require 'spec_helper'

RSpec.describe Prawn::SVG::CSS::SelectorParser do
  describe "::parse" do
    it "parses a simple selector" do
      expect(described_class.parse("div")).to eq [{name: "div"}]
      expect(described_class.parse(".c1")).to eq [{class: ["c1"]}]
    end

    it "parses a complex selector" do
      result = described_class.parse("div#count .c1.c2 > span.large + div~.other:first-child *:nth-child(3)")
      expect(result).to eq [
        {name: "div", id: ["count"]},
        {combinator: :descendant, class: ["c1", "c2"]},
        {combinator: :child, name: "span", class: ["large"]},
        {combinator: :adjacent, name: "div"},
        {combinator: :siblings, class: ["other"], pseudo_class: ["first-child"]},
        {combinator: :descendant, name: "*", pseudo_class: ["nth-child(3)"]},
      ]
    end
  end
end
