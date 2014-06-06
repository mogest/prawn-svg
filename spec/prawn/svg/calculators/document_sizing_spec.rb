require File.dirname(__FILE__) + '/../../../spec_helper'

describe Prawn::Svg::Calculators::DocumentSizing do
  let(:attributes) do
    {"width" => "150", "height" => "200", "viewBox" => "0 -30 300 800", "preserveAspectRatio" => "xMaxYMid meet"}
  end

  let(:bounds) { [1200, 800] }

  let(:sizing) { Prawn::Svg::Calculators::DocumentSizing.new(bounds, attributes) }

  describe "#initialize" do
    it "takes bounds and a set of attributes and calls set_from_attributes" do
      expect(sizing.instance_variable_get :@bounds).to eq bounds
      expect(sizing.instance_variable_get :@document_width).to eq "150"
    end
  end

  describe "#set_from_attributes" do
    let(:sizing) { Prawn::Svg::Calculators::DocumentSizing.new(bounds) }

    it "sets ivars from the passed-in attributes hash" do
      sizing.set_from_attributes(attributes)
      expect(sizing.instance_variable_get :@document_width).to eq "150"
      expect(sizing.instance_variable_get :@document_height).to eq "200"
      expect(sizing.instance_variable_get :@view_box).to eq "0 -30 300 800"
      expect(sizing.instance_variable_get :@preserve_aspect_ratio).to eq "xMaxYMid meet"
    end
  end

  describe "#calculate" do
    it "calculates the document sizing measurements for a given set of inputs" do
      sizing.calculate
      expect(sizing.x_offset).to eq -75
      expect(sizing.y_offset).to eq -30
      expect(sizing.x_scale).to eq 0.25
      expect(sizing.y_scale).to eq 0.25
      expect(sizing.viewport_width).to eq 300
      expect(sizing.viewport_height).to eq 800
      expect(sizing.output_width).to eq 150
      expect(sizing.output_height).to eq 200
    end

    it "scales again based on requested width" do
      sizing.requested_width = 75
      sizing.calculate
      expect(sizing.x_scale).to eq 0.125
      expect(sizing.y_scale).to eq 0.125
      expect(sizing.viewport_width).to eq 300
      expect(sizing.viewport_height).to eq 800
      expect(sizing.output_width).to eq 75
      expect(sizing.output_height).to eq 100
    end

    it "scales again based on requested height" do
      sizing.requested_height = 100
      sizing.calculate
      expect(sizing.x_scale).to eq 0.125
      expect(sizing.y_scale).to eq 0.125
      expect(sizing.viewport_width).to eq 300
      expect(sizing.viewport_height).to eq 800
      expect(sizing.output_width).to eq 75
      expect(sizing.output_height).to eq 100
    end

    it "correctly handles % values being passed in" do
      sizing.document_width = sizing.document_height = "50%"
      sizing.calculate
      expect(sizing.output_width).to eq 600
      expect(sizing.output_height).to eq 400
    end
  end
end
