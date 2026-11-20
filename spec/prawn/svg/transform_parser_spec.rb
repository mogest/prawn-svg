require 'spec_helper'

RSpec.describe Prawn::SVG::TransformParser do
  class Test
    include Prawn::SVG::Calculators::Pixels
    include Prawn::SVG::TransformParser

    State = Struct.new(:viewport_sizing)
    Properties = Struct.new(:numeric_font_size)
    Document = Struct.new(:sizing)

    def document
      Document.new(_sizing)
    end

    def state
      State.new(_sizing)
    end

    def computed_properties
      Properties.new(14)
    end

    def _sizing
      Prawn::SVG::Calculators::DocumentSizing.new([1000, 800])
    end
  end

  subject { Test.new.parse_transform_attribute(transform) }

  context 'with no transform' do
    let(:transform) { '' }
    it { is_expected.to eq Matrix[[1, 0, 0], [0, 1, 0], [0, 0, 1]] }
  end

  context 'with an unknown function' do
    let(:transform) { 'skew(10)' }

    it 'reports it as invalid' do
      test = Test.new
      expect(test).to receive(:add_issue).with(:invalid, "Unknown transformation 'skew'; ignoring")
      test.parse_transform_attribute(transform)
    end
  end

  context 'with a number outside the single-precision range' do
    let(:transform) { 'translate(10) scale(1e39)' }

    it 'reports it as invalid and ignores the transform' do
      test = Test.new
      expect(test).to receive(:add_issue).with(:invalid, "Invalid number in transform 'translate(10) scale(1e39)'; ignoring")
      expect(test.parse_transform_attribute(transform)).to eq Matrix.identity(3)
    end
  end

  context 'with transforms that together are too large' do
    let(:transform) { 'scale(1e38) scale(1e38) scale(1e38) scale(1e38) scale(1e38) scale(1e38) scale(1e38) scale(1e38) scale(1e38)' }

    it 'reports it as invalid and ignores the transform' do
      test = Test.new
      expect(test).to receive(:add_issue).with(:invalid, "transform '#{transform}' is too large; ignoring")
      expect(test.parse_transform_attribute(transform)).to eq Matrix.identity(3)
    end
  end

  context 'with many unclosed brackets' do
    let(:transform) { 'a(' * 100_000 }
    it { is_expected.to eq Matrix.identity(3) }
  end

  context 'with a long name and no closing bracket' do
    let(:transform) { "#{' ' * 100_000}#{'a' * 100_000}(" }
    it { is_expected.to eq Matrix.identity(3) }
  end

  context 'with translate' do
    let(:transform) { 'translate(10 20)' }
    it { is_expected.to eq Matrix[[1, 0, 10.0], [0, 1, -20.0], [0, 0, 1.0]] }
  end

  context 'with single argument translate' do
    let(:transform) { 'translate(10)' }
    it { is_expected.to eq Matrix[[1, 0, 10.0], [0, 1, 0.0], [0, 0, 1.0]] }
  end

  context 'with translateX' do
    let(:transform) { 'translateX(10)' }
    it { is_expected.to eq Matrix[[1, 0, 10.0], [0, 1, 0.0], [0, 0, 1.0]] }
  end

  context 'with translateY' do
    let(:transform) { 'translateY(10)' }
    it { is_expected.to eq Matrix[[1, 0, 0.0], [0, 1, -10.0], [0, 0, 1.0]] }
  end

  let(:sin30) { Math.sin(30 * Math::PI / 180.0) }
  let(:cos30) { Math.cos(30 * Math::PI / 180.0) }
  let(:tan30) { Math.tan(30 * Math::PI / 180.0) }

  context 'with single argument rotate' do
    let(:transform) { 'rotate(30)' }
    it { is_expected.to eq Matrix[[cos30, sin30, 0], [-sin30, cos30, 0], [0.0, 0.0, 1]] }
  end

  context 'with triple argument rotate' do
    let(:transform) { 'rotate(30 100 200)' }
    it { is_expected.to eq Matrix[[cos30, sin30, 113.39745962155611], [-sin30, cos30, 23.205080756887753], [0.0, 0.0, 1.0]] }
  end

  context 'with two argument rotate' do
    let(:transform) { 'rotate(30 100)' }

    it 'reports it as invalid' do
      test = Test.new
      expect(test).to receive(:add_issue).with(:invalid, "transform 'rotate' must have either one or three arguments")
      expect(test.parse_transform_attribute(transform)).to eq Matrix.identity(3)
    end
  end

  context 'with scale' do
    let(:transform) { 'scale(1.5)' }
    it { is_expected.to eq Matrix[[1.5, 0.0, 0], [0.0, 1.5, 0], [0.0, 0.0, 1]] }
  end

  context 'with skewX' do
    let(:transform) { 'skewX(30)' }
    it { is_expected.to eq Matrix[[1, -tan30, 0], [0, 1.0, 0], [0, 0.0, 1]] }
  end

  context 'with skewY' do
    let(:transform) { 'skewY(30)' }
    it { is_expected.to eq Matrix[[1.0, 0, 0], [-tan30, 1, 0], [0.0, 0, 1]] }
  end

  context 'with matrix' do
    let(:transform) { 'matrix(1 2 3 4 5 6)' }
    it { is_expected.to eq Matrix[[1.0, -3.0, 5.0], [-2.0, 4.0, -6.0], [0.0, 0.0, 1.0]] }
  end

  context 'with a matrix missing an argument' do
    let(:transform) { 'matrix(1 2 3 4 5)' }

    it 'reports it as invalid' do
      test = Test.new
      expect(test).to receive(:add_issue).with(:invalid, "transform 'matrix' must have six arguments")
      expect(test.parse_transform_attribute(transform)).to eq Matrix.identity(3)
    end
  end

  context 'with multiple' do
    let(:transform) { 'scale(2) translate(7) scale(3)' }
    it { is_expected.to eq Matrix[[6.0, 0.0, 14.0], [0.0, 6.0, 0.0], [0.0, 0.0, 1.0]] }
  end
end
