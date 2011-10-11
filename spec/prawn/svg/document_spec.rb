require File.dirname(__FILE__) + '/../../spec_helper'

describe Prawn::Svg::Document do  
  before(:each) do
    @document = Prawn::Svg::Document.new("<svg></svg>", [100, 100], {})
  end

  describe :points do    
    it "converts a variety of measurement units to points" do
      @document.send(:points, 32).should == 32.0      
      @document.send(:points, 32.0).should == 32.0      
      @document.send(:points, "32").should == 32.0
      @document.send(:points, "32unknown").should == 32.0
      @document.send(:points, "32pt").should == 32.0      
      @document.send(:points, "32in").should == 32.0 * 72
      @document.send(:points, "32ft").should == 32.0 * 72 * 12
      @document.send(:points, "32mm").should be_within(0.0001).of(32 * 72 * 0.0393700787)
      @document.send(:points, "32cm").should be_within(0.0001).of(32 * 72 * 0.393700787)
      @document.send(:points, "32m").should be_within(0.0001).of(32 * 72 * 39.3700787)
      
      @document.send :instance_variable_set, "@actual_width", 600
      @document.send :instance_variable_set, "@actual_height", 400
      @document.send(:points, "50%").should == 300
      @document.send(:points, "50%", :y).should == 200
    end
  end
end
