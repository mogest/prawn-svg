require 'spec_helper'

describe Prawn::Svg do  
  describe "sample file rendering" do
    root = "#{File.dirname(__FILE__)}/../.."
    files = Dir["#{root}/spec/sample_svg/*.svg"]
    
    it "has at least 10 SVG sample files to test" do
      files.length.should >= 10
    end
    
    files.each do |file|
      it "renders the #{File.basename file} sample file without crashing" do
        Prawn::Document.generate("#{root}/spec/sample_output/#{File.basename file}.pdf") do
          svg IO.read(file), :at => [0, y], :width => 500
        end
      end
    end
  end
end
