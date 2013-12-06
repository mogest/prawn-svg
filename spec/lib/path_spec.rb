require 'spec_helper'

describe Prawn::Svg::Parser::Path do
  before :each do
    @path = Prawn::Svg::Parser::Path.new
  end

  describe "command parsing" do
    it "correctly parses a valid path" do
      calls = []
      @path.stub!(:run_path_command) {|*args| calls << args}
      @path.parse("A12.34 -56.78 89B4 5 12-34 -.5.7+3 2.3e3 4e4 4e+4 c31,-2e-5C  6,7 T QX 0 Z")

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
        @path.should_receive(:run_path_command).with(*args).and_call_original
      end

      @path.parse("M 1,2 3,4 m 5,6 7,8")
    end

    it "correctly parses an empty path" do
      @path.should_not_receive(:run_path_command)
      @path.parse("").should == []
      @path.parse("   ").should == []
    end

    it "raises on invalid characters in the path" do
      lambda {@path.parse("M 10 % 20")}.should raise_error(Prawn::Svg::Parser::Path::InvalidError)
    end

    it "raises on numerical data before a command letter" do
      lambda {@path.parse("10 P")}.should raise_error(Prawn::Svg::Parser::Path::InvalidError)
    end
  end
end
