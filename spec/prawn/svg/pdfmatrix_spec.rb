require 'spec_helper'

RSpec.describe Prawn::SVG::PDFMatrix do
  subject do
    obj = Object.new
    obj.extend(Prawn::SVG::PDFMatrix)
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
    let(:angle) { 45 * Math::PI / 180.0 }
    let(:inv_root_2) { 0.707 }

    context 'in PDF space' do
      it 'returns the expected matrix' do
        matrix = Matrix[[inv_root_2, inv_root_2, 0], [-inv_root_2, inv_root_2, 0], [0, 0, 1]]
        expect(subject.rotation_matrix(angle).round(3)).to eq(matrix)
      end
    end

    context 'in SVG space' do
      it 'returns the expected matrix' do
        matrix = Matrix[[inv_root_2, -inv_root_2, 0], [inv_root_2, inv_root_2, 0], [0, 0, 1]]
        expect(subject.rotation_matrix(angle, space: :svg).round(3)).to eq(matrix)
      end
    end
  end
end
