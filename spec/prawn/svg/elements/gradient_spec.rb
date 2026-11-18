require 'spec_helper'

describe Prawn::SVG::Elements::Gradient do
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], { width: 800, height: 600 }) }
  let(:root_element) { Prawn::SVG::Elements::Root.new(document, document.root, []) }
  let(:element) { document.gradients['flag'] }

  before do
    root_element.process
  end

  describe 'stop offsets with units' do
    let(:svg) do
      <<-SVG
        <linearGradient id="flag">
          <stop offset="1em" stop-color="red"/>
          <stop offset="0.5" stop-color="blue"/>
        </linearGradient>
      SVG
    end

    it 'treats them as zero' do
      expect(element.stops.map { |stop| stop[:offset] }).to eq [0.0, 0.5, 1]
    end
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

    it 'returns correct gradient arguments for an element with no bounding box' do
      arguments = element.gradient_arguments(double(bounding_box: nil, stroke_width: 0))
      expect(arguments).to eq(
        from:         [0.0, 0.0],
        to:           [0.2, 1.0],
        wrap:         :pad,
        matrix:       Matrix[[1.0, 0.0, 0.0], [0.0, -1.0, 600.0], [0.0, 0.0, 1.0]],
        bounding_box: nil,
        stops:        [
          { offset: 0, color: 'ff0000', opacity: 1.0 },
          { offset: 0.25, color: 'ff0000', opacity: 1.0 },
          { offset: 0.5, color: 'ffffff', opacity: 1.0 },
          { offset: 0.75, color: '0000ff', opacity: 1.0 },
          { offset: 1, color: '0000ff', opacity: 1.0 }
        ]
      )
    end

    it 'returns correct gradient arguments for an element' do
      arguments = element.gradient_arguments(double(bounding_box: [100, 100, 200, 0], stroke_width: 0))
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
      arguments = element.gradient_arguments(double(bounding_box: [100, 100, 200, 0], stroke_width: 0))
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
      arguments = element.gradient_arguments(double(bounding_box: [100, 100, 200, 0], stroke_width: 0))
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
      arguments = element.gradient_arguments(double(bounding_box: [100, 100, 200, 0], stroke_width: 0))
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
      arguments = element.gradient_arguments(double(bounding_box: [100, 100, 200, 0], stroke_width: 0))

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
      arguments = document.gradients['flag-2'].gradient_arguments(double(bounding_box: [100, 100, 200, 0], stroke_width: 0))
      expect(arguments).to eq(
        from:         [150.0, 500.0],
        to:           [220.0, 600.0],
        stops:        [{ offset: 0, color: 'ff0000', opacity: 1.0 }, { offset: 1, color: '0000ff', opacity: 1.0 }],
        matrix:       Matrix[[1.0, 0.0, 0.0], [0.0, -1.0, 600.0], [0.0, 0.0, 1.0]],
        wrap:         :pad,
        bounding_box: [100, 100, 200, 0]
      )

      arguments = document.gradients['flag-3'].gradient_arguments(double(bounding_box: [100, 100, 200, 0], stroke_width: 0))
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

  describe 'href loop' do
    let(:svg) do
      %(<svg><linearGradient id="p" href="#q"/><linearGradient id="q" href="#p"/><rect width="10" height="10" fill="url(#p)"/></svg>)
    end

    it 'reports an issue' do
      expect(document.warnings).to include "gradient or pattern 'q' is in a reference loop"
    end
  end

  describe 'many references to a gradient with many stops' do
    let(:svg) do
      stops = (0..10).map { |n| %(<stop offset="#{n / 10.0}" stop-color="red"/>) }.join
      %(<svg xmlns="http://www.w3.org/2000/svg"><linearGradient id="flag">#{stops}</linearGradient>#{'<rect width="1" height="1" fill="url(#flag)"/>' * 20}</svg>)
    end

    it "counts each reference's stops towards the work budget" do
      expect { Prawn::Document.new.svg(svg, max_work: 5000) }.not_to raise_error
      expect { Prawn::Document.new.svg(svg, max_work: 500) }.to raise_error Prawn::SVG::Document::WorkLimitExceeded
    end

    it 'counts the stops of every copy made by a pattern' do
      stops = (0..10).map { |n| %(<stop offset="#{n / 10.0}" stop-color="red"/>) }.join
      pattern = %(<pattern id="p" width="10" height="10" patternUnits="userSpaceOnUse"><rect width="10" height="10" fill="url(#flag)"/></pattern>)
      rects = '<rect width="1" height="1" fill="url(#p)"/>' * 20
      patterned = %(<svg xmlns="http://www.w3.org/2000/svg"><linearGradient id="flag">#{stops}</linearGradient>#{pattern}#{rects}</svg>)

      expect { Prawn::Document.new.svg(patterned, max_work: 500) }.to raise_error Prawn::SVG::Document::WorkLimitExceeded
    end
  end

  describe 'stop properties' do
    let(:svg) do
      <<-SVG
        <svg>
          <g color="red" stop-color="blue" stop-opacity="0.3">
            <linearGradient id="flag" stop-opacity="0.5">
              <stop offset="0" stop-color="currentColor"/>
              <stop offset="0.5" stop-opacity="inherit"/>
              <stop offset="1" stop-color="inherit"/>
            </linearGradient>
          </g>
        </svg>
      SVG
    end

    it 'uses their computed values, defaulting to black' do
      expect(element.stops).to eq [
        { offset: 0.0, color: 'ff0000', opacity: 1.0 },
        { offset: 0.5, color: '000000', opacity: 0.5 },
        { offset: 1.0, color: '000000', opacity: 1.0 }
      ]
    end
  end

  describe 'stops with lengths, and other children' do
    let(:svg) do
      <<-SVG
        <svg>
          <style>* { stroke-dasharray: 2 }</style>
          <radialGradient id="flag">
            <stop offset="0" stroke-width="5"/>
            <rect stroke-width="5"/>
          </radialGradient>
        </svg>
      SVG
    end

    it 'processes the stops in the viewport' do
      expect(element.stops.map { |stop| stop[:offset] }).to eq [0.0, 1]
    end
  end

  describe 'userSpaceOnUse defaults' do
    let(:svg) do
      <<-SVG
        <svg width="200" height="100">
          <linearGradient id="flag" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="red"/></linearGradient>
          <radialGradient id="radial" gradientUnits="userSpaceOnUse" cx="20" cy="30"><stop offset="0" stop-color="red"/></radialGradient>
        </svg>
      SVG
    end
    let(:shape) { double(bounding_box: [0, 100, 200, 0], stroke_width: 0) }

    it 'runs a linear gradient from 0% 0% to 100% 0%' do
      expect(element.gradient_arguments(shape)).to include(from: [0.0, 0.0], to: [200.0, 0.0])
    end

    it 'puts the focal point of a radial gradient at its centre' do
      expect(document.gradients['radial'].gradient_arguments(shape)).to include(from: [20.0, 30.0], to: [20.0, 30.0])
    end
  end

  describe 'degenerate gradients' do
    let(:svg) do
      <<-SVG
        <svg>
          <linearGradient id="flag" x1="0.3" x2="0.3"><stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue" stop-opacity="0.5"/></linearGradient>
          <radialGradient id="radial" r="0" href="#flag"/>
          <radialGradient id="focal" fx="2" fy="0.5" href="#flag"/>
          <linearGradient id="singular" gradientTransform="scale(0)" href="#flag"/>
        </svg>
      SVG
    end
    let(:shape) { double(bounding_box: [0, 100, 200, 0], stroke_width: 0) }
    let(:last_stop_arguments) do
      {
        from:         [0.0, 0.0],
        to:           [1.0, 0.0],
        stops:        [{ offset: 0.0, color: '0000ff', opacity: 0.5 }, { offset: 1.0, color: '0000ff', opacity: 0.5 }],
        bounding_box: [0, 100, 200, 0]
      }
    end

    it 'paints a zero-length linear gradient with its last stop' do
      expect(element.gradient_arguments(shape)).to eq last_stop_arguments
    end

    it 'paints a zero-radius radial gradient with its last stop' do
      expect(document.gradients['radial'].gradient_arguments(shape)).to eq last_stop_arguments
    end

    it 'moves a focal point outside the circle to just inside it' do
      expect(document.gradients['focal'].gradient_arguments(shape)[:from]).to eq [0.9995, 0.5]
    end

    it 'paints nothing when the gradient has no area' do
      expect(document.gradients['singular'].gradient_arguments(shape)[:stops].map { |stop| stop[:opacity] }).to eq [0.0, 0.0]
      expect(element.gradient_arguments(double(bounding_box: [0, 100, 200, 100], stroke_width: 0))[:stops].map { |stop| stop[:opacity] }).to eq [0.0, 0.0]
    end
  end

  describe 'a gradient without valid stops' do
    let(:svg) { '<svg><rect width="10" height="10" fill="url(#flag)"/><linearGradient id="flag"/></svg>' }

    it 'is not used' do
      expect(element).to be_nil
      expect(document.warnings).to include 'gradient does not have any valid stops', 'Could not resolve fill URI to a gradient or pattern element'
    end
  end

  describe 'an href to a pattern' do
    let(:svg) do
      <<-SVG
        <svg>
          <pattern id="p" width="5" height="5"><rect width="2" height="2"/></pattern>
          <linearGradient id="flag" href="#p"/>
          <pattern id="q" href="#flag" width="5" height="5"/>
          <rect width="10" height="10" fill="url(#q)"/>
        </svg>
      SVG
    end

    it 'is ignored' do
      expect(element).to be_nil
      expect(document.warnings).to include 'gradient does not have any valid stops'
    end
  end

  describe 'spreadMethod on degenerate gradients' do
    let(:svg) { '<svg/>' }

    stops = '<stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>'
    {
      'a tiny vector'                         => %(<linearGradient id="g" x2="1e-320" spreadMethod="reflect">#{stops}</linearGradient>),
      'a huge vector'                         => %(<linearGradient id="g" x1="1e308%" spreadMethod="reflect">#{stops}</linearGradient>),
      'a nearly singular transform'           => %(<linearGradient id="g" gradientTransform="matrix(1e-200 0 0 1e-200 0 0)" spreadMethod="repeat">#{stops}</linearGradient>),
      'a focal circle larger than the circle' => %(<radialGradient id="g" fr="0.7" spreadMethod="reflect">#{stops}</radialGradient>),
      'a focal point far from a huge centre'  => %(<radialGradient id="g" cx="1e308" fx="-1e308">#{stops}</radialGradient>),
      'an overflowing transform'              => %(<linearGradient id="g" gradientTransform="scale(1e300)">#{stops}</linearGradient>),
      'a huge centre'                         => %(<radialGradient id="g" cx="1e308" spreadMethod="reflect">#{stops}</radialGradient>)
    }.each do |description, gradient|
      it "pads #{description}" do
        pdf = Prawn::Document.new(compress: false)
        pdf.svg(%(<svg width="100" height="100">#{gradient}<rect width="10" height="3e38" fill="url(#g)"/></svg>))
        expect(pdf.render).not_to match(/\b(?:NaN|Inf|null)\b/)
      end
    end
  end
end
