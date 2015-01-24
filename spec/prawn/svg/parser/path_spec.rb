require 'spec_helper'

describe Prawn::Svg::Parser::Path do
  let(:path) { Prawn::Svg::Parser::Path.new }

  describe "command parsing" do
    it "correctly parses a valid path" do
      calls = []
      path.stub(:run_path_command) {|*args| calls << args}
      path.parse("A12.34 -56.78 89B4 5 12-34 -.5.7+3 2.3e3 4e4 4e+4 c31,-2e-5C  6,7 T QX 0 Z")

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

    it "treats subsequent points to m/M command as relative/absolute depending on command" do
      [
        ["M", [1,2,3,4]],
        ["L", [3,4]],
        ["m", [5,6,7,8]],
        ["l", [7,8]]
      ].each do |args|
        path.should_receive(:run_path_command).with(*args).and_call_original
      end

      path.parse("M 1,2 3,4 m 5,6 7,8")
    end

    it "correctly parses an empty path" do
      path.should_not_receive(:run_path_command)
      path.parse("").should == []
      path.parse("   ").should == []
    end

    it "raises on invalid characters in the path" do
      lambda {path.parse("M 10 % 20")}.should raise_error(Prawn::Svg::Parser::Path::InvalidError)
    end

    it "raises on numerical data before a command letter" do
      lambda {path.parse("10 P")}.should raise_error(Prawn::Svg::Parser::Path::InvalidError)
    end
  end

  context "when given an A path" do
    it "uses bezier curves to approximate an arc path" do
      result = path.parse("M 100 200 A 10 10 0 0 1 200 200")

      expect(result).to eq [
        ["move_to", [100.0, 200.0]],
        ["curve_to", [150.0, 150.0, 100.0, 172.57081148225683, 122.57081148225683, 150.0]],
        ["curve_to", [200.0, 200.0, 177.42918851774317, 150.0, 200.0, 172.57081148225683]]
      ]
    end

    it "ignores a path that has an identical start and end point" do
      result = path.parse("M 100 200 A 30 30 0 0 1 100 200")

      expect(result).to eq [
        ["move_to", [100.0, 200.0]]
      ]
    end

    it "substitutes a line_to when rx is 0" do
      result = path.parse("M 100 200 A 0 10 0 0 1 200 200")

      expect(result).to eq [
        ["move_to", [100.0, 200.0]],
        ["line_to", [200.0, 200.0]]
      ]
    end

    it "substitutes a line_to when ry is 0" do
      result = path.parse("M 100 200 A 10 0 0 0 1 200 200")

      expect(result).to eq [
        ["move_to", [100.0, 200.0]],
        ["line_to", [200.0, 200.0]]
      ]
    end
  end
end
