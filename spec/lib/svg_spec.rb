require 'spec_helper'

describe Prawn::Svg do  
  describe "sample file rendering" do
    root = "#{File.dirname(__FILE__)}/../.."
    files = Dir["#{root}/spec/sample_svg/*.svg"]
    
    it "has at least 10 SVG sample files to test" do
      files.length.should >= 10
    end
    
    files.each do |file|
      it "renders the #{File.basename file} sample file without warnings or crashing" do
        Prawn::Document.generate("#{root}/spec/sample_output/#{File.basename file}.pdf") do
          r = svg IO.read(file), :at => [0, y], :width => 500
          r[:warnings].should == []
        end
      end
    end
  end
end
