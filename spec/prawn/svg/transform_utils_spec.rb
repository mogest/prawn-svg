require 'spec_helper'

RSpec.describe Prawn::SVG::TransformUtils do
  subject do
    obj = Object.new
    obj.extend(Prawn::SVG::TransformUtils)
    obj
  end

  describe '#load_matrix' do
    it 'converts a PDF-style matrix into a Ruby Matrix' do
      expect(subject.load_matrix([1.0, 0.0, 0.0, 1.0, 5.0, 7.0])).to eq(Matrix[
        [1.0, 0.0, 5.0],
        [0.0, 1.0, 7.0],
        [0.0, 0.0, 1.0]
      ])
    end

    it 'returns the same Ruby Matrix if it has the correct dimensions' do
      matrix = Matrix[[1.0, 0.0, 5.0], [0.0, 1.0, 7.0], [0.0, 0.0, 1.0]]
      expect(subject.load_matrix(matrix)).to eq(matrix)
    end

    it 'raises an error for unexpected Ruby matrices' do
      matrix = Matrix.identity(4)
      expect { subject.load_matrix(matrix) }.to raise_error(ArgumentError)
    end

    it 'raises an error for unexpected PDF-style matrices' do
      matrix = [1.0, 2.0, 3.0, 4.0]
      expect { subject.load_matrix(matrix) }.to raise_error(ArgumentError)
    end
  end

  describe '#matrix_for_pdf' do
    it 'converts a Ruby Matrix into the correct format for PDF' do
      matrix = Matrix[[1.0, 0.0, 5.0], [0.0, 1.0, 7.0], [0.0, 0.0, 1.0]]
      expect(subject.matrix_for_pdf(matrix)).to eq([1.0, 0.0, 0.0, 1.0, 5.0, 7.0])
    end
  end

  describe '#rotation_matrix' do
    it '' do
      p = Vector[1, 0, 1]
      mat = subject.rotation_matrix(45 * Math::PI / 180.0)
      puts mat * p
    end
  end
end
