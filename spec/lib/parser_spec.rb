require 'spec_helper'

describe Prawn::Svg::Parser do
  before(:each) do
    @svg = Prawn::Svg::Parser.new(nil, [100, 100], {})
  end
  
  describe "document width and height" do
    it "handles the width and height being set as a %" do
      svg = <<-SVG
        <svg width="50%" height="50%" version="1.1">
          <line x1="10%" y1="10%" x2="90%" y2="90%" />
        </svg>
      SVG
    
      parser = Prawn::Svg::Parser.new(svg, [2000, 2000], {})
      parser.parse.last.last.should == [["line", [100.0, 900.0, 900.0, 100.0], []]]
    end

    it "handles the width and height being set in inches" do
      svg = <<-SVG
        <svg width="10in" height="10in" version="1.1">
          <line x1="1in" y1="1in" x2="9in" y2="9in" />
        </svg>
      SVG
    
      parser = Prawn::Svg::Parser.new(svg, [2000, 2000], {})
      parser.parse.last.last.should == [["line", [72.0, 720.0 - 72.0, 720.0 - 72.0, 72.0], []]]
    end
  end
  
  describe :parse_element do
    def mock_element(name, attributes = {})
      mock("Element").tap do |m|
        m.stub!(:name).and_return(name)
        m.stub!(:attributes).and_return(attributes)
      end
    end
    
    it "ignores tags it doesn't know about" do
      calls = []
      @svg.send :parse_element, mock_element("unknown"), calls, {}
      calls.should == []
      @svg.warnings.length.should == 1
      @svg.warnings.first.should include("Unknown tag")
    end
    
    it "ignores tags that don't have all required attributes set" do
      calls = []
      @svg.send :parse_element, mock_element("ellipse", "rx" => "1"), calls, {}
      calls.should == []
      @svg.warnings.length.should == 1
      @svg.warnings.first.should include("Must have attributes ry on tag ellipse")
    end
  end
  
  describe :color_to_hex do
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
  
  describe :points do
    it "converts a variety of measurement units to points" do
      @svg.send(:points, 32).should == 32.0      
      @svg.send(:points, 32.0).should == 32.0      
      @svg.send(:points, "32").should == 32.0
      @svg.send(:points, "32unknown").should == 32.0
      @svg.send(:points, "32pt").should == 32.0      
      @svg.send(:points, "32in").should == 32.0 * 72
      @svg.send(:points, "32ft").should == 32.0 * 72 * 12
      @svg.send(:points, "32mm").should be_close(32 * 72 * 0.0393700787, 0.0001)
      @svg.send(:points, "32cm").should be_close(32 * 72 * 0.393700787, 0.0001)
      @svg.send(:points, "32m").should be_close(32 * 72 * 39.3700787, 0.0001)
      
      @svg.send :instance_variable_set, "@actual_width", 600
      @svg.send :instance_variable_set, "@actual_height", 400
      @svg.send(:points, "50%").should == 300
      @svg.send(:points, "50%", :y).should == 200
    end
  end
  
  describe :map_font_family_to_pdf_font do
    it "matches a built in font" do
      @svg.send(:map_font_family_to_pdf_font, "blah, 'courier', nothing").should == 'Courier'
    end
    
    it "matches a default font" do
      @svg.send(:map_font_family_to_pdf_font, "serif").should == 'Times-Roman'
      @svg.send(:map_font_family_to_pdf_font, "blah, serif").should == 'Times-Roman'
      @svg.send(:map_font_family_to_pdf_font, "blah, serif , test").should == 'Times-Roman'
    end
    
    if File.exists?("/Library/Fonts")
      it "matches a font installed on the system" do
        @svg.send(:map_font_family_to_pdf_font, "verdana, sans-serif").should == '/Library/Fonts/Verdana.ttf'
        @svg.send(:map_font_family_to_pdf_font, "something, \"Times New Roman\", serif").should == '/Library/Fonts/Times New Roman.ttf'
        @svg.send(:map_font_family_to_pdf_font, "something, Times New Roman, serif").should == '/Library/Fonts/Times New Roman.ttf'
      end
    else
      it "not running font test because there is no /Library/Font directory"
    end
    
    it "returns nil if it can't find any such font" do
      @svg.send(:map_font_family_to_pdf_font, "blah, thing").should be_nil
      @svg.send(:map_font_family_to_pdf_font, "").should be_nil      
    end
  end
end
