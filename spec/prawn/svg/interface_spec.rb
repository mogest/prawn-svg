require 'spec_helper'

describe Prawn::Svg::Interface do
  let(:bounds) { double(width: 800, height: 600) }
  let(:prawn)  { instance_double(Prawn::Document, font_families: {}, bounds: bounds, cursor: 600) }
  let(:svg)    { '<svg width="250" height="100"></svg>' }

  describe "#initialize" do
    describe "invalid option detection" do
      it "rejects invalid options when debug is on" do
        allow(Prawn).to receive(:debug).and_return(true)

        expect {
          Prawn::Svg::Interface.new(svg, prawn, :invalid => "option")
        }.to raise_error(Prawn::Errors::UnknownOption)
      end

      it "does nothing if an invalid option is given and debug is off" do
        Prawn::Svg::Interface.new(svg, prawn, :invalid => "option")
      end
    end
  end

  describe "#position" do
    context "when options[:at] supplied" do
      it "returns options[:at]" do
        interface = Prawn::Svg::Interface.new(svg, prawn, at: [1, 2], position: :left)

        expect(interface.position).to eq [1, 2]
      end
    end

    context "when only a position is supplied" do
      let(:interface) { Prawn::Svg::Interface.new(svg, prawn, position: position) }

      subject { interface.position }

      context "(:left)" do
        let(:position) { :left }
        it { is_expected.to eq [0, 600] }
      end

      context "(:center)" do
        let(:position) { :center }
        it { is_expected.to eq [275, 600] }
      end

      context "(:right)" do
        let(:position) { :right }
        it { is_expected.to eq [550, 600] }
      end

      context "a number" do
        let(:position) { 25.5 }
        it { is_expected.to eq [25.5, 600] }
      end
    end
  end
end
