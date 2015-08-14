require 'spec_helper'

describe Prawn::SVG::Elements::Base do
  let(:svg) { "<svg></svg>" }
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], {}) }
  let(:parent_calls) { [] }
  let(:element) { Prawn::SVG::Elements::Base.new(document, document.root, parent_calls, {}) }

  describe "#initialize" do
    let(:svg) { '<something id="hello"/>' }

    it "adds itself to the elements_by_id hash if an id attribute is supplied" do
      element
      expect(document.elements_by_id["hello"]).to eq element
    end
  end

  describe "#process" do
    it "calls #parse and #apply so subclasses can parse the element" do
      expect(element).to receive(:parse).ordered
      expect(element).to receive(:apply).ordered
      element.process
    end

    describe "applying calls from the standard attributes" do
      let(:svg) do
        <<-SVG
          <something transform="rotate(90)" fill-opacity="0.5" fill="red" stroke="blue" stroke-width="5" font-family="Helvetica"/>
        SVG
      end

      it "appends the relevant calls" do
        element.process
        expect(element.base_calls).to eq [
          ["rotate", [-90.0, {origin: [0, 150.0]}], [
            ["transparent", [0.5, 1], [
              ["fill_color", ["ff0000"], []],
              ["stroke_color", ["0000ff"], []],
              ["line_width", [5.0], []],
              ["font", ["Helvetica", {:style=>:normal}], [
                ["fill_and_stroke", [], []]
              ]]
            ]]
          ]]
        ]
      end
    end

    it "appends calls to the parent element" do
      expect(element).to receive(:apply) do
        element.send :add_call, "test", "argument"
      end

      element.process
      expect(element.parent_calls).to eq [["end_path", [], [["test", ["argument"], []]]]]
    end

    it "quietly absorbs a SkipElementQuietly exception" do
      expect(element).to receive(:parse).and_raise(Prawn::SVG::Elements::Base::SkipElementQuietly)
      expect(element).to_not receive(:apply)
      element.process
      expect(document.warnings).to be_empty
    end

    it "absorbs a SkipElementError exception, logging a warning" do
      expect(element).to receive(:parse).and_raise(Prawn::SVG::Elements::Base::SkipElementError, "hello")
      expect(element).to_not receive(:apply)
      element.process
      expect(document.warnings).to eq ["hello"]
    end
  end

  describe "#parse_fill_and_stroke_attributes_and_call" do
    before do
      element.send(:combine_attributes_and_style_declarations)
    end

    subject { element.send :parse_fill_and_stroke_attributes_and_call }

    it "doesn't change anything if no fill attribute provided" do
      subject
      expect(element.state[:fill]).to be nil
    end

    it "doesn't change anything if 'inherit' fill attribute provided" do
      element.attributes['fill'] = 'inherit'
      subject
      expect(element.state[:fill]).to be nil
    end

    it "turns off filling if 'none' fill attribute provided" do
      element.attributes['fill'] = 'none'
      subject
      expect(element.state[:fill]).to be false
    end

    it "uses the fill attribute's color" do
      expect(element).to receive(:add_call).with('fill_color', 'ff0000')
      element.attributes['fill'] = 'red'
      subject
      expect(element.state[:fill]).to be true
    end

    it "uses black if the fill attribute's color is unparseable" do
      expect(element).to receive(:add_call).with('fill_color', '000000')
      element.attributes['fill'] = 'blarble'
      subject
      expect(element.state[:fill]).to be true
    end

    it "uses the color attribute if 'currentColor' fill attribute provided" do
      expect(element).to receive(:add_call).with('fill_color', 'ff0000')
      element.attributes['fill'] = 'currentColor'
      element.attributes['color'] = 'red'
      subject
      expect(element.state[:fill]).to be true
    end

    it "turns off filling if UnresolvableURLWithNoFallbackError is raised" do
      element.attributes['fill'] = 'url()'
      subject
      expect(element.state[:fill]).to be false
    end
  end
end
