require 'spec_helper'

describe Prawn::SVG::Elements::Gradient do
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], { width: 800, height: 600 }) }
  let(:root_element) { Prawn::SVG::Elements::Root.new(document, document.root, []) }
  let(:element) { document.gradients['flag'] }

  before do
    root_element.process
  end

  describe 'object bounding box with linear gradient' do
    let(:svg) do
      <<-SVG
        <linearGradient id="flag" x1="0" x2="0.2" y1="0" y2="1">
          <stop offset="25%" stop-color="red"/>
          <stop offset="50%" stop-color="white"/>
          <stop offset="75%" stop-color="blue"/>
        </linearGradient>
      SVG
    end

    it 'is stored in the document gradients table' do
      expect(document.gradients['flag']).to eq element
    end

    it 'returns correct gradient arguments for an element' do
      arguments = element.gradient_arguments(double(bounding_box: [100, 100, 200, 0]))
      expect(arguments).to eq(
        from:         [0.0, 0.0],
        to:           [0.2, 1.0],
        wrap:         :pad,
        matrix:       Matrix[[100.0, 0.0, 100.0], [0.0, -100.0, 100.0], [0.0, 0.0, 1.0]],
        bounding_box: [100, 100, 200, 0],
        stops:        [
          { offset: 0, color: 'ff0000', opacity: 1.0 },
          { offset: 0.25, color: 'ff0000', opacity: 1.0 },
          { offset: 0.5, color: 'ffffff', opacity: 1.0 },
          { offset: 0.75, color: '0000ff', opacity: 1.0 },
          { offset: 1, color: '0000ff', opacity: 1.0 }
        ]
      )
    end
  end

  describe 'object bounding box with radial gradient' do
    let(:svg) do
      <<-SVG
        <radialGradient id="flag" cx="0" cy="0.2" fx="0.5" r="0.8">
          <stop offset="25%" stop-color="red"/>
          <stop offset="50%" stop-color="white"/>
          <stop offset="75%" stop-color="blue"/>
        </radialGradient>
      SVG
    end

    it 'is stored in the document gradients table' do
      expect(document.gradients['flag']).to eq element
    end

    it 'returns correct gradient arguments for an element' do
      arguments = element.gradient_arguments(double(bounding_box: [100, 100, 200, 0]))
      expect(arguments).to eq(
        from:         [0.5, 0.2],
        to:           [0.0, 0.2],
        r1:           0,
        r2:           0.8,
        wrap:         :pad,
        matrix:       Matrix[[100.0, 0.0, 100.0], [0.0, -100.0, 100.0], [0.0, 0.0, 1.0]],
        bounding_box: [100, 100, 200, 0],
        stops:        [
          { offset: 0, color: 'ff0000', opacity: 1.0 },
          { offset: 0.25, color: 'ff0000', opacity: 1.0 },
          { offset: 0.5, color: 'ffffff', opacity: 1.0 },
          { offset: 0.75, color: '0000ff', opacity: 1.0 },
          { offset: 1, color: '0000ff', opacity: 1.0 }
        ]
      )
    end
  end

  describe 'user space on use with linear gradient' do
    let(:svg) do
      <<-SVG
        <linearGradient id="flag" gradientUnits="userSpaceOnUse" x1="100" y1="500" x2="200" y2="600">
          <stop offset="0" stop-color="red"/>
          <stop offset="1" stop-color="blue"/>
        </linearGradient>
      SVG
    end

    it 'returns correct gradient arguments for an element' do
      arguments = element.gradient_arguments(double(bounding_box: [100, 100, 200, 0]))
      expect(arguments).to eq(
        from:         [100.0, 500.0],
        to:           [200.0, 600.0],
        stops:        [{ offset: 0, color: 'ff0000', opacity: 1.0 }, { offset: 1, color: '0000ff', opacity: 1.0 }],
        matrix:       Matrix[[1.0, 0.0, 0.0], [0.0, -1.0, 600.0], [0.0, 0.0, 1.0]],
        wrap:         :pad,
        bounding_box: [100, 100, 200, 0]
      )
    end
  end

  describe 'user space on use with radial gradient' do
    let(:svg) do
      <<-SVG
        <radialGradient id="flag" gradientUnits="userSpaceOnUse" fx="100" fy="500" cx="200" cy="600" r="150">
          <stop offset="0" stop-color="red"/>
          <stop offset="1" stop-color="blue"/>
        </radialGradient>
      SVG
    end

    it 'returns correct gradient arguments for an element' do
      arguments = element.gradient_arguments(double(bounding_box: [100, 100, 200, 0]))
      expect(arguments).to eq(
        from:         [100.0, 500.0],
        to:           [200.0, 600.0],
        r1:           0,
        r2:           150.0,
        stops:        [{ offset: 0, color: 'ff0000', opacity: 1.0 }, { offset: 1, color: '0000ff', opacity: 1.0 }],
        matrix:       Matrix[[1.0, 0.0, 0.0], [0.0, -1.0, 600.0], [0.0, 0.0, 1.0]],
        wrap:         :pad,
        bounding_box: [100, 100, 200, 0]
      )
    end
  end

  context 'when gradientTransform is specified' do
    let(:svg) do
      <<-SVG
        <linearGradient id="flag" gradientTransform="translateX(0.5) scale(2)" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="red"/>
          <stop offset="1" stop-color="blue"/>
        </linearGradient>
      SVG
    end

    it 'passes in the transform via the apply_transformations option' do
      arguments = element.gradient_arguments(double(bounding_box: [100, 100, 200, 0]))

      expect(arguments).to eq(
        from:         [0.0, 0.0],
        to:           [1.0, 1.0],
        stops:        [{ offset: 0, color: 'ff0000', opacity: 1.0 }, { offset: 1, color: '0000ff', opacity: 1.0 }],
        matrix:       Matrix[[200.0, 0.0, 150.0], [0.0, -200.0, 100.0], [0.0, 0.0, 1.0]],
        wrap:         :pad,
        bounding_box: [100, 100, 200, 0]
      )
    end
  end

  context 'when a gradient is linked to another' do
    let(:svg) do
      <<-SVG
        <svg>
          <linearGradient id="flag" gradientUnits="userSpaceOnUse" x1="100" y1="500" x2="200" y2="600">
            <stop offset="0" stop-color="red"/>
            <stop offset="1" stop-color="blue"/>
          </linearGradient>

          <linearGradient id="flag-2" href="#flag" x1="150" x2="220" />

          <linearGradient id="flag-3" href="#flag-2" x1="170" />
        </svg>
      SVG
    end

    it 'correctly inherits the attributes from the parent element' do
      arguments = document.gradients['flag-2'].gradient_arguments(double(bounding_box: [100, 100, 200, 0]))
      expect(arguments).to eq(
        from:         [150.0, 500.0],
        to:           [220.0, 600.0],
        stops:        [{ offset: 0, color: 'ff0000', opacity: 1.0 }, { offset: 1, color: '0000ff', opacity: 1.0 }],
        matrix:       Matrix[[1.0, 0.0, 0.0], [0.0, -1.0, 600.0], [0.0, 0.0, 1.0]],
        wrap:         :pad,
        bounding_box: [100, 100, 200, 0]
      )

      arguments = document.gradients['flag-3'].gradient_arguments(double(bounding_box: [100, 100, 200, 0]))
      expect(arguments).to eq(
        from:         [170.0, 500.0],
        to:           [220.0, 600.0],
        stops:        [{ offset: 0, color: 'ff0000', opacity: 1.0 }, { offset: 1, color: '0000ff', opacity: 1.0 }],
        matrix:       Matrix[[1.0, 0.0, 0.0], [0.0, -1.0, 600.0], [0.0, 0.0, 1.0]],
        wrap:         :pad,
        bounding_box: [100, 100, 200, 0]
      )
    end
  end
end
