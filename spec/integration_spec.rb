require 'spec_helper'

describe Prawn::Svg::Interface do
  root = "#{File.dirname(__FILE__)}/.."

  context "with option :position" do
    let(:svg) { IO.read("#{root}/spec/sample_svg/cubic01a.svg") }

    it "aligns the image as requested" do
      Prawn::Document.generate("#{root}/spec/sample_output/_with_position.pdf") do |prawn|
        width = prawn.bounds.width / 3

        prawn.svg svg, :width => width, :position => :left
        prawn.svg svg, :width => width, :position => :center
        prawn.svg svg, :width => width, :position => :right
        prawn.svg svg, :width => width, :position => 50
        prawn.svg svg, :width => width
      end
    end
  end

  context "with option :vposition" do
    let(:svg) { IO.read("#{root}/spec/sample_svg/cubic01a.svg") }

    it "aligns the image as requested" do
      Prawn::Document.generate("#{root}/spec/sample_output/_with_vposition.pdf") do |prawn|
        width = prawn.bounds.width / 3

        prawn.svg svg, :width => width, :position => :left, :vposition => :bottom
        prawn.svg svg, :width => width, :position => :center, :vposition => :center
        prawn.svg svg, :width => width, :position => :right, :vposition => :top
        prawn.svg svg, :width => width, :position => 50, :vposition => 50
      end
    end
  end

  describe "sample file rendering" do
    files = Dir["#{root}/spec/sample_svg/*.svg"]

    it "has at least 10 SVG sample files to test" do
      files.length.should >= 10
    end

    files.each do |file|
      it "renders the #{File.basename file} sample file without warnings or crashing" do
        warnings = nil
        Prawn::Document.generate("#{root}/spec/sample_output/#{File.basename file}.pdf") do |prawn|
          r = prawn.svg IO.read(file), :at => [0, prawn.bounds.top], :width => prawn.bounds.width do |doc|
            doc.url_loader.enable_web = false
            doc.url_loader.url_cache["https://raw.githubusercontent.com/mogest/prawn-svg/master/spec/sample_images/mushroom-wide.jpg"] = IO.read("#{root}/spec/sample_images/mushroom-wide.jpg")
            doc.url_loader.url_cache["https://raw.githubusercontent.com/mogest/prawn-svg/master/spec/sample_images/mushroom-long.jpg"] = IO.read("#{root}/spec/sample_images/mushroom-long.jpg")
          end

          warnings = r[:warnings].reject {|w| w =~ /Verdana/ && w =~ /is not a known font/ }
        end
        warnings.should == []
      end
    end
  end

  describe "multiple file rendering" do
    it "renders multiple files on to the same PDF" do
      Prawn::Document.generate("#{root}/spec/sample_output/_multiple.pdf") do |prawn|
        width = prawn.bounds.width

        y = prawn.bounds.top - 12
        prawn.draw_text "This is multiple SVGs being output to the same PDF", :at => [0, y]

        y -= 12
        prawn.svg IO.read("#{root}/spec/sample_svg/arcs01.svg"),   :at => [0, y],         :width => width / 2
        prawn.svg IO.read("#{root}/spec/sample_svg/circle01.svg"), :at => [width / 2, y], :width => width / 2

        y -= 120
        prawn.draw_text "Here are some more PDFs below", :at => [0, y]

        y -= 12
        prawn.svg IO.read("#{root}/spec/sample_svg/quad01.svg"), :at => [0, y],             :width => width / 3
        prawn.svg IO.read("#{root}/spec/sample_svg/rect01.svg"), :at => [width / 3, y],     :width => width / 3
        prawn.svg IO.read("#{root}/spec/sample_svg/rect02.svg"), :at => [width / 3 * 2, y], :width => width / 3
      end
    end
  end
end
