require 'spec_helper'

describe Prawn::SVG::Elements::Style do
  let(:svg) do
    <<-SVG
<style>a
  before&gt;
  x <![CDATA[ y
  inside <>&gt;
  k ]]> j
  after
z</style>
    SVG
  end

  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], {}) }
  let(:element) { Prawn::SVG::Elements::Style.new(document, document.root, [], {}) }

  it "correctly collects the style information in a <style> tag" do
    expect(document.css_parser).to receive(:add_block!).with("a\n  before>\n  x  y\n  inside <>&gt;\n  k  j\n  after\nz")
    element.process
  end
end
