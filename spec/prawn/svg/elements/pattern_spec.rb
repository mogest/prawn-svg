require 'spec_helper'

describe Prawn::SVG::Elements::Pattern do
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], { width: 800, height: 600 }) }
  let(:root_element) { Prawn::SVG::Elements::Root.new(document, document.root, []) }
  let(:element) { document.gradients['pat'] }

  before do
    root_element.process
  end

  describe 'userSpaceOnUse pattern' do
    let(:svg) do
      <<-SVG
        <svg>
          <pattern id="pat" x="10" y="20" width="50" height="30" patternUnits="userSpaceOnUse">
            <rect width="50" height="30" fill="red"/>
          </pattern>
          <rect id="r" x="0" y="0" width="200" height="100" fill="url(#pat)"/>
        </svg>
      SVG
    end

    it 'is stored in the document gradients table' do
      expect(element).to be_a(Prawn::SVG::Elements::Pattern)
    end

    it 'returns pattern arguments with correct tile geometry' do
      mock_element = double(bounding_box: [0, 600, 200, 500], stroke_width: 0)
      args = element.pattern_arguments(mock_element)

      expect(args[:tile_x]).to eq 10.0
      expect(args[:tile_y]).to eq 550.0 # output_height(600) - svg_y(20) - height(30)
      expect(args[:tile_width]).to eq 50.0
      expect(args[:tile_height]).to eq 30.0
      expect(args[:transform]).to eq Matrix.identity(3)
      expect(args[:calls]).to be_an(Array)
      expect(args[:calls]).not_to be_empty
    end

    it 'returns nil when width is zero' do
      allow(element).to receive(:derive_attribute).and_call_original
      allow(element).to receive(:derive_attribute).with('width').and_return('0')

      mock_element = double(bounding_box: [0, 600, 200, 500], stroke_width: 0)
      expect(element.pattern_arguments(mock_element)).to be_nil
    end
  end

  describe 'objectBoundingBox pattern' do
    let(:svg) do
      <<-SVG
        <svg>
          <pattern id="pat" x="0.1" y="0.2" width="0.5" height="0.25" patternUnits="objectBoundingBox">
            <rect width="100%" height="100%" fill="blue"/>
          </pattern>
          <rect id="r" x="100" y="100" width="200" height="100" fill="url(#pat)"/>
        </svg>
      SVG
    end

    it 'computes tile geometry relative to the bounding box' do
      # bbox in Prawn coords: [left=100, top=500, right=300, bottom=400]
      bbox = [100, 500, 300, 400]
      mock_element = double(bounding_box: bbox, stroke_width: 0)
      args = element.pattern_arguments(mock_element)

      # bbox_w = 200, bbox_h = 100
      # tile_w = 0.5 * 200 = 100
      # tile_h = 0.25 * 100 = 25
      # tile_x = 100 + 0.1 * 200 = 120
      # tile_y_top = 500 - 0.2 * 100 = 480
      # tile_y_bottom = 480 - 25 = 455
      expect(args[:tile_x]).to eq 120.0
      expect(args[:tile_y]).to eq 455.0
      expect(args[:tile_width]).to eq 100.0
      expect(args[:tile_height]).to eq 25.0
    end

    it 'returns nil when bounding box is nil' do
      mock_element = double(bounding_box: nil, stroke_width: 0)
      expect(element.pattern_arguments(mock_element)).to be_nil
    end
  end

  describe 'objectBoundingBox pattern with units, percentages and exponents' do
    let(:svg) do
      <<-SVG
        <svg>
          <pattern id="pat" x="10%" y="0.2px" width="0.5px" height="2.5e-1" patternUnits="objectBoundingBox">
            <rect width="100%" height="100%" fill="blue"/>
          </pattern>
          <rect id="r" x="100" y="100" width="200" height="100" fill="url(#pat)"/>
        </svg>
      SVG
    end

    it 'computes the same tile geometry as plain numbers' do
      args = element.pattern_arguments(double(bounding_box: [100, 500, 300, 400], stroke_width: 0))
      expect(args.values_at(:tile_x, :tile_y, :tile_width, :tile_height)).to eq [120.0, 455.0, 100.0, 25.0]
    end
  end

  describe 'patternTransform' do
    let(:svg) do
      <<-SVG
        <svg>
          <pattern id="pat" width="40" height="40" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
            <rect width="40" height="40" fill="red"/>
          </pattern>
          <rect x="0" y="0" width="200" height="100" fill="url(#pat)"/>
        </svg>
      SVG
    end

    it 'includes the transform matrix' do
      mock_element = double(bounding_box: [0, 600, 200, 500], stroke_width: 0)
      args = element.pattern_arguments(mock_element)

      expect(args[:transform]).not_to eq Matrix.identity(3)
    end
  end

  describe 'viewBox' do
    let(:svg) do
      <<-SVG
        <svg>
          <pattern id="pat" width="50" height="50" patternUnits="userSpaceOnUse" viewBox="0 0 10 10">
            <circle cx="5" cy="5" r="4" fill="orange"/>
          </pattern>
          <rect x="0" y="0" width="200" height="100" fill="url(#pat)"/>
        </svg>
      SVG
    end

    it 'includes viewBox transform calls in content' do
      mock_element = double(bounding_box: [0, 600, 200, 500], stroke_width: 0)
      args = element.pattern_arguments(mock_element)

      # Should have transformation_matrix calls for viewBox scaling
      transform_calls = args[:calls].select { |c| c[0] == 'transformation_matrix' }
      expect(transform_calls).not_to be_empty
    end
  end

  describe 'href inheritance' do
    let(:svg) do
      <<-SVG
        <svg>
          <pattern id="base" x="0" y="0" width="40" height="40" patternUnits="userSpaceOnUse">
            <rect width="20" height="20" fill="red"/>
          </pattern>
          <pattern id="pat" href="#base" x="10" y="10"/>
          <rect x="0" y="0" width="200" height="100" fill="url(#pat)"/>
        </svg>
      SVG
    end

    it 'inherits attributes from the parent pattern' do
      expect(element.derive_attribute('width')).to eq '40'
      expect(element.derive_attribute('height')).to eq '40'
      expect(element.derive_attribute('patternUnits')).to eq 'userSpaceOnUse'
    end

    it 'overrides attributes specified on the child' do
      expect(element.derive_attribute('x')).to eq '10'
      expect(element.derive_attribute('y')).to eq '10'
    end

    it 'inherits content from parent when child has none' do
      mock_element = double(bounding_box: [0, 600, 200, 500], stroke_width: 0)
      args = element.pattern_arguments(mock_element)

      expect(args[:calls]).not_to be_empty
    end
  end

  describe 'objectBoundingBox content units' do
    let(:svg) do
      <<-SVG
        <svg>
          <pattern id="pat" width="0.5" height="0.5" patternUnits="objectBoundingBox" patternContentUnits="objectBoundingBox">
            <rect width="0.25" height="0.25" fill="purple"/>
          </pattern>
          <rect x="100" y="100" width="200" height="100" fill="url(#pat)"/>
        </svg>
      SVG
    end

    it 'returns content calls scaled to the bounding box' do
      bbox = [100, 500, 300, 400]
      mock_element = double(bounding_box: bbox, stroke_width: 0)
      args = element.pattern_arguments(mock_element)

      expect(args[:calls]).not_to be_empty
    end

    it 'returns nil when bounding box is nil' do
      mock_element = double(bounding_box: nil, stroke_width: 0)
      expect(element.pattern_arguments(mock_element)).to be_nil
    end
  end

  describe 'pattern without id' do
    let(:svg) do
      <<-SVG
        <svg>
          <pattern width="40" height="40">
            <rect width="40" height="40" fill="red"/>
          </pattern>
        </svg>
      SVG
    end

    it 'is silently skipped' do
      expect(document.gradients['anything']).to be_nil
    end
  end

  describe 'integration with fill' do
    let(:svg) do
      <<-SVG
        <svg width="200" height="200">
          <defs>
            <pattern id="pat" x="0" y="0" width="20" height="20" patternUnits="userSpaceOnUse">
              <rect width="10" height="10" fill="red"/>
              <rect x="10" y="10" width="10" height="10" fill="red"/>
            </pattern>
          </defs>
          <rect width="200" height="200" fill="url(#pat)"/>
        </svg>
      SVG
    end

    it 'generates svg:render_pattern calls' do
      calls = root_element.base_calls.flatten(1)
      calls.find { |c| c.is_a?(Array) && c[0] == 'svg:render_pattern' }

      # The pattern call should exist somewhere in the call tree
      found = find_call(root_element.base_calls, 'svg:render_pattern')
      expect(found).to be true
    end
  end

  def find_call(calls, name)
    calls.any? do |call_name, _args, _kwargs, children|
      call_name == name || (children && find_call(children, name))
    end
  end

  describe 'href loop' do
    let(:svg) do
      %(<svg><pattern id="p" href="#q" width="5" height="5"/><pattern id="q" href="#p" width="5" height="5"/><rect width="10" height="10" fill="url(#p)"/></svg>)
    end

    it 'reports an issue' do
      expect(document.warnings).to include "gradient or pattern 'q' is in a reference loop"
    end
  end

  describe 'objectBoundingBox content that references its own pattern' do
    let(:svg) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <pattern id="pat" width="1" height="1" patternContentUnits="objectBoundingBox"><rect width="1" height="1" fill="url(#pat)"/></pattern>
          <rect width="10" height="10" fill="url(#pat)"/>
        </svg>
      SVG
    end

    it 'skips the content that references it and reports an invalid issue' do
      root_element.process

      expect(document.issues).to eq [Prawn::SVG::Issue.new(:invalid, '<pattern> references itself')]
    end
  end

  describe 'a link in pattern content' do
    let(:svg) do
      link = '<a href="svg:render"><rect width="5" height="5"/></a>'
      pattern = %(<pattern id="pat" width="10" height="10" patternUnits="userSpaceOnUse">#{link}</pattern>)
      %(<svg xmlns="http://www.w3.org/2000/svg">#{pattern}<rect width="10" height="10" fill="url(#pat)"/></svg>)
    end

    it 'copies the link, whatever its href' do
      expect { root_element.process }.not_to raise_error
    end
  end

  describe 'fan-out through nested patterns' do
    let(:svg) { '<svg></svg>' }

    it 'counts copied pattern content towards the work budget' do
      patterns = (0...10).map do |n|
        rect = %(<rect width="5" height="5" fill="url(#p#{n + 1})"/>)
        %(<pattern id="p#{n}" width="10" height="10" patternUnits="userSpaceOnUse">#{rect}#{rect}</pattern>)
      end
      fan_out = %(<svg>#{patterns.join}<pattern id="p10" width="1" height="1"><rect width="1" height="1"/></pattern><rect width="10" height="10" fill="url(#p0)"/></svg>)
      document = Prawn::SVG::Document.new(fan_out, [800, 600], { max_work: 10_000 })

      expect { Prawn::SVG::Elements::Root.new(document, document.root, []).process }.to raise_error Prawn::SVG::Document::WorkLimitExceeded
    end
  end
end
