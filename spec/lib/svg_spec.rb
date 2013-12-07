require 'spec_helper'

describe Prawn::Svg::Interface do
  describe "sample file rendering" do
    root = "#{File.dirname(__FILE__)}/../.."
    files = Dir["#{root}/spec/sample_svg/*.svg"]

    it "has at least 10 SVG sample files to test" do
      files.length.should >= 10
    end

    files.each do |file|
      it "renders the #{File.basename file} sample file without warnings or crashing" do
        warnings = nil
        Prawn::Document.generate("#{root}/spec/sample_output/#{File.basename file}.pdf") do |prawn|
          r = prawn.svg IO.read(file), :at => [0, prawn.bounds.top], :width => prawn.bounds.width, :cache_images => true
          warnings = r[:warnings].reject {|w| w =~ /Verdana/ && w =~ /is not a known font/ }
        end
        warnings.should == []
      end
    end
  end
end
