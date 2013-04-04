require File.dirname(__FILE__) + '/../../spec_helper'

describe Prawn::Svg::Element do
  before :each do
    e = mock
    e.stub!(:attributes).and_return({})

    @document = Struct.new(:fallback_font_name, :css_parser, :warnings).new("Courier", nil, [])
    @element = Prawn::Svg::Element.new(@document, e, [], {})
  end

  describe :parse_font_attributes_and_call do
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
end
