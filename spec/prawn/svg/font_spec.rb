require File.dirname(__FILE__) + '/../../spec_helper'

describe Prawn::Svg::Font do
  describe :map_font_family_to_pdf_font do    
    it "matches a built in font" do
      Prawn::Svg::Font.map_font_family_to_pdf_font("blah, 'courier', nothing").should == 'Courier'
    end
    
    it "matches a default font" do
      Prawn::Svg::Font.map_font_family_to_pdf_font("serif").should == 'Times-Roman'
      Prawn::Svg::Font.map_font_family_to_pdf_font("blah, serif").should == 'Times-Roman'
      Prawn::Svg::Font.map_font_family_to_pdf_font("blah, serif , test").should == 'Times-Roman'
    end
    
    if !Prawn::Svg::Font.installed_fonts.empty?
      it "matches a font installed on the system" do
        Prawn::Svg::Font.map_font_family_to_pdf_font("verdana, sans-serif").should == 'verdana'
        Prawn::Svg::Font.map_font_family_to_pdf_font("VERDANA, sans-serif").should == 'verdana'
        Prawn::Svg::Font.map_font_family_to_pdf_font("something, \"Times New Roman\", serif").should == "times new roman"
        Prawn::Svg::Font.map_font_family_to_pdf_font("something, Times New Roman, serif").should == "times new roman"
      end
    else
      it "not running font test because we couldn't find a font directory"
    end
    
    it "returns nil if it can't find any such font" do
      Prawn::Svg::Font.map_font_family_to_pdf_font("blah, thing").should be_nil
      Prawn::Svg::Font.map_font_family_to_pdf_font("").should be_nil      
    end
  end
end
