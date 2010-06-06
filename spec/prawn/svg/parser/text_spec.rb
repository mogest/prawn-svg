require File.dirname(__FILE__) + '/../../../spec_helper'

describe Prawn::Svg::Parser::Text do  
  describe :map_font_family_to_pdf_font do
    before :each do
      @svg = Prawn::Svg::Parser::Text.new
    end
    
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
