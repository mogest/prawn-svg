require File.dirname(__FILE__) + '/../../spec_helper'

describe Prawn::Svg::Element do
  before :each do
    e = mock
    e.stub!(:attributes).and_return({})
    @element = Prawn::Svg::Element.new(nil, e, [], {})
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
end
