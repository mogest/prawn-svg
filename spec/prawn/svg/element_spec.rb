require File.dirname(__FILE__) + '/../../spec_helper'

describe Prawn::Svg::Element do
  let(:document) { double(css_parser: nil) }
  let(:e) { double(:attributes => {}, :name => "path") }
  let(:element) { Prawn::Svg::Element.new(document, e, [], {}) }

  describe "#parse_font_attributes_and_call" do
    before do
      @document = Struct.new(:fallback_font_name, :css_parser, :warnings).new("Courier", nil, [])
      @element = Prawn::Svg::Element.new(@document, e, [], {})
    end

    it "uses a font if it can find it" do
      @element.should_receive(:add_call_and_enter).with('font', 'Helvetica', :style => :normal)

      @element.attributes["font-family"] = "Helvetica"
      @element.send :parse_font_attributes_and_call
    end

    it "uses the fallback font if the requested font is not defined" do
      @element.should_receive(:add_call_and_enter).with('font', 'Courier', :style => :normal)

      @element.attributes["font-family"] = "Font That Doesn't Exist"
      @element.send :parse_font_attributes_and_call
    end

    it "doesn't call the font method if there's no fallback font" do
      @document.fallback_font_name = nil

      @element.should_not_receive(:add_call_and_enter)

      @element.attributes["font-family"] = "Font That Doesn't Exist"
      @element.send :parse_font_attributes_and_call
      @document.warnings.length.should == 1
    end
  end

  describe "#parse_fill_and_stroke_attributes_and_call" do
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

  describe "#parse_transform_attribute_and_call" do
    subject { element.send :parse_transform_attribute_and_call }

    describe "translate" do
      it "handles a missing y argument" do
        expect(element).to receive(:add_call_and_enter).with('translate', -5.5, 0)
        expect(document).to receive(:distance).with(-5.5, :x).and_return(-5.5)
        expect(document).to receive(:distance).with(0.0, :y).and_return(0.0)

        element.attributes['transform'] = 'translate(-5.5)'
        subject
      end
    end

    describe "rotate" do
      it "handles a single angle argument" do
        expect(element).to receive(:add_call_and_enter).with('rotate', -5.5, :origin => [0, 0])
        expect(document).to receive(:y).with('0').and_return(0)

        element.attributes['transform'] = 'rotate(5.5)'
        subject
      end

      it "handles three arguments" do
        expect(element).to receive(:add_call_and_enter).with('rotate', -5.5, :origin => [1.0, 2.0])
        expect(document).to receive(:x).with(1.0).and_return(1.0)
        expect(document).to receive(:y).with(2.0).and_return(2.0)

        element.attributes['transform'] = 'rotate(5.5 1 2)'
        subject
      end

      it "does nothing and warns if two arguments" do
        expect(document).to receive(:warnings).and_return([])
        element.attributes['transform'] = 'rotate(5.5 1)'
        subject
      end
    end
  end
end
