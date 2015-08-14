require 'spec_helper'

describe Prawn::SVG::Elements::Path do
  let(:source) { double(name: "path", attributes: {}) }
  let(:path) { Prawn::SVG::Elements::Path.new(nil, source, [], {}) }

  before do
    allow(path).to receive(:attributes).and_return("d" => d)
  end

  describe "command parsing" do
    context "with a valid path" do
      let(:d) { "A12.34 -56.78 89B4 5 12-34 -.5.7+3 2.3e3 4e4 4e+4 c31,-2e-5C  6,7 T QX 0 Z" }

      it "correctly parses" do
        calls = []
        path.stub(:run_path_command) {|*args| calls << args}
        path.parse

        calls.should == [
          ["A", [12.34, -56.78, 89]],
          ["B", [4, 5, 12, -34, -0.5, 0.7, 3, 2.3e3, 4e4, 4e4]],
          ["c", [31, -2e-5]],
          ["C", [6, 7]],
          ["T", []],
          ["Q", []],
          ["X", [0]],
          ["Z", []]
        ]
      end
    end

    context "with m and M commands" do
      let(:d) { "M 1,2 3,4 m 5,6 7,8" }

      it "treats subsequent points to m/M command as relative/absolute depending on command" do
        [
          ["M", [1,2,3,4]],
          ["L", [3,4]],
          ["m", [5,6,7,8]],
          ["l", [7,8]]
        ].each do |args|
          path.should_receive(:run_path_command).with(*args).and_call_original
        end

        path.parse
      end
    end

    context "with an empty path" do
      let(:d) { "" }

      it "correctly parses" do
        path.should_not_receive(:run_path_command)
        path.parse
      end
    end

    context "with a path with invalid characters" do
      let(:d) { "M 10 % 20" }

      it "raises" do
        expect { path.parse }.to raise_error(Prawn::SVG::Elements::Base::SkipElementError)
      end
    end

    context "with a path with numerical data before a command letter" do
      let(:d) { "M 10 % 20" }

      it "raises" do
        expect { path.parse }.to raise_error(Prawn::SVG::Elements::Base::SkipElementError)
      end
    end
  end

  context "when given an A path" do
    subject { path.parse; path.commands }

    context "that is pretty normal" do
      let(:d) { "M 100 200 A 10 10 0 0 1 200 200" }

      it "uses bezier curves to approximate an arc path" do
        expect(subject).to eq [
          ["move_to", [100.0, 200.0]],
          ["curve_to", [150.0, 150.0, 100.0, 172.57081148225683, 122.57081148225683, 150.0]],
          ["curve_to", [200.0, 200.0, 177.42918851774317, 150.0, 200.0, 172.57081148225683]]
        ]
      end
    end

    context "with an identical start and end point" do
      let(:d) { "M 100 200 A 30 30 0 0 1 100 200" }

      it "ignores the path" do
        expect(subject).to eq [
          ["move_to", [100.0, 200.0]]
        ]
      end
    end
    
    context "with an rx of 0" do
      let(:d) { "M 100 200 A 0 10 0 0 1 200 200" }

      it "substitutes a line_to" do
        expect(subject).to eq [
          ["move_to", [100.0, 200.0]],
          ["line_to", [200.0, 200.0]]
        ]
      end
    end

    context "with an ry of 0" do
      let(:d) { "M 100 200 A 10 0 0 0 1 200 200" }

      it "substitutes a line_to" do
        expect(subject).to eq [
          ["move_to", [100.0, 200.0]],
          ["line_to", [200.0, 200.0]]
        ]
      end
    end
  end
end
