require 'spec_helper'

describe Prawn::Svg::Parser do
  describe "document width and height" do
    it "handles the width and height being set as a %" do
      svg = <<-SVG
        <svg width="50%" height="50%" version="1.1">
          <line x1="10%" y1="10%" x2="90%" y2="90%" />
        </svg>
      SVG
    
      document = Prawn::Svg::Document.new(svg, [2000, 2000], {})
      Prawn::Svg::Parser.new(document).parse[-2][-1].should == [["line", [100.0, 900.0, 900.0, 100.0], []]]
    end

    it "handles the width and height being set in inches" do
      svg = <<-SVG
        <svg width="10in" height="10in" version="1.1">
          <line x1="1in" y1="1in" x2="9in" y2="9in" />
        </svg>
      SVG
    
      document = Prawn::Svg::Document.new(svg, [2000, 2000], {})
      Prawn::Svg::Parser.new(document).parse[-2][-1].should == [["line", [72.0, 720.0 - 72.0, 720.0 - 72.0, 72.0], []]]
    end
  end
  
  describe :parse_element do
    before(:each) do
      @document = Prawn::Svg::Document.new("<svg></svg>", [100, 100], {})
      @parser = Prawn::Svg::Parser.new(@document)
    end
    
    def mock_element(name, attributes = {})
      e = mock
      e.stub!(:name).and_return(name)
      e.stub!(:attributes).and_return(attributes)

      Prawn::Svg::Element.new(@document, e, [], {})
    end
    
    it "ignores tags it doesn't know about" do
      calls = []
      @parser.send :parse_element, mock_element("unknown")
      calls.should == []
      @document.warnings.length.should == 1
      @document.warnings.first.should include("Unknown tag")
    end
    
    it "ignores tags that don't have all required attributes set" do
      calls = []
      @parser.send :parse_element, mock_element("ellipse", "rx" => "1")
      calls.should == []
      @document.warnings.length.should == 1
      @document.warnings.first.should include("Must have attributes ry on tag ellipse")
    end
  end
end
