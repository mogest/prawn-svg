require File.dirname(__FILE__) + '/../../spec_helper'

describe Prawn::Svg::Font do
  describe :load do
    it "matches a built in font" do
      Prawn::Svg::Font.load("blah, 'courier', nothing").name.should == 'Courier'
    end

    it "matches a default font" do
      Prawn::Svg::Font.load("serif").name.should == 'Times-Roman'
      Prawn::Svg::Font.load("blah, serif").name.should == 'Times-Roman'
      Prawn::Svg::Font.load("blah, serif , test").name.should == 'Times-Roman'
    end

    Prawn::Svg::Font.load_external_fonts({})

    if !Prawn::Svg::Font.installed_fonts.empty?
      it "matches a font installed on the system" do
        Prawn::Svg::Font.load("verdana, sans-serif").name.should == 'Verdana'
        Prawn::Svg::Font.load("VERDANA, sans-serif").name.should == 'Verdana'
        Prawn::Svg::Font.load("something, \"Times New Roman\", serif").name.should == "Times New Roman"
        Prawn::Svg::Font.load("something, Times New Roman, serif").name.should == "Times New Roman"
      end
    else
      it "not running font test because we couldn't find a font directory"
    end

    it "returns nil if it can't find any such font" do
      Prawn::Svg::Font.load("blah, thing").should be_nil
      Prawn::Svg::Font.load("").should be_nil
    end
  end
end
