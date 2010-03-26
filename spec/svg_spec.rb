require 'spec_helper'
require 'prawn'

describe Prawn::Svg do
  describe :color_to_hex do
    before(:each) do
      @svg = Prawn::Svg.new(nil, nil, {})
    end
    
    it "converts #xxx to a hex value" do
      @svg.send(:color_to_hex, "#9ab").should == "99aabb"
    end

    it "converts #xxxxxx to a hex value" do
      @svg.send(:color_to_hex, "#9ab123").should == "9ab123"
    end
    
    it "converts an html colour name to a hex value" do
      @svg.send(:color_to_hex, "White").should == "ffffff"
    end
    
    it "converts an rgb string to a hex value" do      
      @svg.send(:color_to_hex, "rgb(16, 32, 48)").should == "102030"
      @svg.send(:color_to_hex, "rgb(-5, 50%, 120%)").should == "007fff"
    end
    
    it "scans the string and finds the first colour it can parse" do
      @svg.send(:color_to_hex, "function(#someurl, 0) nonexistent rgb( 3 ,4,5 ) white").should == "030405"
    end
  end
  
  it "renders all sample svg files without crashing" do
    Dir["spec/sample_svg/*.svg"].each do |file|
      Prawn::Document.generate("spec/sample_output/#{File.basename file}.pdf") do
        svg IO.read(file), :at => [0, y], :width => 500
      end
    end
  end
end
