require File.dirname(__FILE__) + '/../../spec_helper'

describe Prawn::Svg::Element do
  before :each do
    e = mock
    e.stub!(:attributes).and_return({})

    @document = Struct.new(:fallback_font_name, :css_parser, :warnings).new("Courier", nil, [])
    @element = Prawn::Svg::Element.new(@document, e, [], {})
  end

  describe :color_to_hex do
    it "converts #xxx to a hex value" do
      @element.send(:color_to_hex, "#9ab").should == "99aabb"
    end

    it "converts #xxxxxx to a hex value" do
      @element.send(:color_to_hex, "#9ab123").should == "9ab123"
    end

    it "converts an html colour name to a hex value" do
      @element.send(:color_to_hex, "White").should == "ffffff"
    end

    it "converts an rgb string to a hex value" do
      @element.send(:color_to_hex, "rgb(16, 32, 48)").should == "102030"
      @element.send(:color_to_hex, "rgb(-5, 50%, 120%)").should == "007fff"
    end

    it "scans the string and finds the first colour it can parse" do
      @element.send(:color_to_hex, "function(#someurl, 0) nonexistent rgb( 3 ,4,5 ) white").should == "030405"
    end
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
