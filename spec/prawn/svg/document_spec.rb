require File.dirname(__FILE__) + '/../../spec_helper'

describe Prawn::SVG::Document do  
  before do
    sizing = instance_double(Prawn::SVG::Calculators::DocumentSizing, viewport_width: 600, viewport_height: 400, viewport_diagonal: 500, :requested_width= => nil, :requested_height= => nil)
    expect(sizing).to receive(:calculate)
    expect(Prawn::SVG::Calculators::DocumentSizing).to receive(:new).and_return(sizing)
  end

  let(:document) { Prawn::SVG::Document.new("<svg></svg>", [100, 100], {}) }

  describe :points do    
    it "converts a variety of measurement units to points" do
      document.send(:points, 32).should == 32.0      
      document.send(:points, 32.0).should == 32.0      
      document.send(:points, "32").should == 32.0
      document.send(:points, "32unknown").should == 32.0
      document.send(:points, "32pt").should == 32.0      
      document.send(:points, "32in").should == 32.0 * 72
      document.send(:points, "32ft").should == 32.0 * 72 * 12
      document.send(:points, "32pc").should == 32.0 * 15
      document.send(:points, "32mm").should be_within(0.0001).of(32 * 72 * 0.0393700787)
      document.send(:points, "32cm").should be_within(0.0001).of(32 * 72 * 0.393700787)
      document.send(:points, "32m").should be_within(0.0001).of(32 * 72 * 39.3700787)

      document.send(:points, "50%").should == 250
      document.send(:points, "50%", :x).should == 300
      document.send(:points, "50%", :y).should == 200
    end
  end
end
