require 'spec_helper'

describe Prawn::SVG::Elements::Root do
  let(:color_mode) { :rgb }
  let(:sizing) do
    instance_double(Prawn::SVG::Calculators::DocumentSizing, x_offset: 0, y_offset: 0, x_scale: 1, y_scale: 1)
  end
  let(:document) do
    instance_double(Prawn::SVG::Document, color_mode: color_mode, sizing: sizing)
  end
  let(:source) { double(name: 'svg', attributes: {}) }
  let(:state) { Prawn::SVG::State.new }
  let(:element) { Prawn::SVG::Elements::Root.new(document, source, [], state) }

  it 'uses RGB black as the default color' do
    element.apply
    expect(element.calls.first).to eq ['fill_color', ['000000'], {}, []]
  end

  context 'when in CMYK mode' do
    let(:color_mode) { :cmyk }

    it 'uses CMYK black as the default color' do
      element.apply
      expect(element.calls.first).to eq ['fill_color', [[0, 0, 0, 100]], {}, []]
    end
  end
end
