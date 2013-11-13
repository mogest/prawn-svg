require 'spec_helper'

describe Prawn::Svg::Parser::Path do
  before :each do
    @path = Prawn::Svg::Parser::Path.new
  end

  describe "command parsing" do
    it "correctly parses a valid path" do
      calls = []
      @path.stub!(:run_path_command) {|*args| calls << args}
      @path.parse("A12.34 -56.78 89B4 5   c31,-2e-5C  6,7 T QX 0 Z")

      calls.should == [
        ["A", [12.34, -56.78, 89]],
        ["B", [4, 5]],
        ["c", [31, -2e-5]],
        ["C", [6, 7]],
        ["T", []],
        ["Q", []],
        ["X", [0]],
        ["Z", []]
      ]
    end

    it "correctly parses a path where a coordinate is separated from another by a leading '-'" do
      calls = []
      @path.stub!(:run_path_command) {|*args| calls << args}
      @path.parse("B4 5c31-2e-5")

      calls.should == [
        ["B", [4, 5]],
        ["c", [31, -2e-5]],
      ]
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
