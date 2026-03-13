require 'spec_helper'

describe Prawn::SVG::Calculators::PathLength do
  let(:move) { Prawn::SVG::Pathable::Move }
  let(:line) { Prawn::SVG::Pathable::Line }
  let(:curve) { Prawn::SVG::Pathable::Curve }
  let(:close) { Prawn::SVG::Pathable::Close }

  describe 'horizontal line' do
    subject { described_class.new([move.new([0, 0]), line.new([100, 0])]) }

    it 'calculates total length' do
      expect(subject.total_length).to eq 100.0
    end

    it 'returns midpoint correctly' do
      x, y, angle = subject.point_at(50)
      expect(x).to eq 50.0
      expect(y).to eq 0.0
      expect(angle).to eq 0.0
    end

    it 'returns start point' do
      x, y, angle = subject.point_at(0)
      expect(x).to eq 0.0
      expect(y).to eq 0.0
      expect(angle).to eq 0.0
    end

    it 'returns end point' do
      x, y, angle = subject.point_at(100)
      expect(x).to eq 100.0
      expect(y).to eq 0.0
      expect(angle).to eq 0.0
    end
  end

  describe 'vertical line' do
    subject { described_class.new([move.new([0, 0]), line.new([0, 100])]) }

    it 'calculates total length' do
      expect(subject.total_length).to eq 100.0
    end

    it 'returns correct 90 degree angle' do
      _, _, angle = subject.point_at(50)
      expect(angle).to eq 90.0
    end
  end

  describe 'multiple segments' do
    subject do
      described_class.new([
                            move.new([0, 0]),
                            line.new([100, 0]),
                            line.new([100, 100])
                          ])
    end

    it 'calculates cumulative total length' do
      expect(subject.total_length).to eq 200.0
    end

    it 'interpolates across segments' do
      x, y, angle = subject.point_at(150)
      expect(x).to eq 100.0
      expect(y).to eq 50.0
      expect(angle).to eq 90.0
    end
  end

  describe 'move command' do
    subject do
      described_class.new([
                            move.new([0, 0]),
                            line.new([50, 0]),
                            move.new([200, 200]),
                            line.new([250, 200])
                          ])
    end

    it 'does not add length for the move' do
      expect(subject.total_length).to eq 100.0
    end
  end

  describe 'close command' do
    subject do
      described_class.new([
                            move.new([0, 0]),
                            line.new([100, 0]),
                            line.new([100, 100]),
                            close.new([0, 0])
                          ])
    end

    it 'adds a line back to the subpath start' do
      expect(subject.total_length).to be_within(0.01).of(200 + Math.sqrt(20_000))
    end
  end

  describe 'cubic bezier' do
    subject do
      described_class.new([
                            move.new([0, 0]),
                            curve.new([100, 0], [33, 50], [66, 50])
                          ])
    end

    it 'calculates a reasonable total length' do
      expect(subject.total_length).to be > 100
      expect(subject.total_length).to be < 200
    end

    it 'returns a midpoint approximately in the right area' do
      x, y, _angle = subject.point_at(subject.total_length / 2.0)
      expect(x).to be_within(10).of(50)
      expect(y).to be > 0
    end
  end

  describe 'edge cases' do
    subject { described_class.new([move.new([0, 0]), line.new([100, 0])]) }

    it 'returns nil for past end' do
      expect(subject.point_at(101)).to be_nil
    end

    it 'returns nil for negative distance' do
      expect(subject.point_at(-1)).to be_nil
    end
  end

  describe 'empty path' do
    subject { described_class.new([move.new([0, 0])]) }

    it 'has zero total length' do
      expect(subject.total_length).to eq 0.0
    end
  end
end
