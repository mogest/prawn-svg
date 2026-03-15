require 'spec_helper'

describe Prawn::SVG::Elements::Mask do
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], { enable_web_requests: false }) }
  let(:element) { Prawn::SVG::Elements::Root.new(document, document.root, []) }
  let(:flattened_calls) { flatten_calls(element.base_calls) }

  def find_call(calls, name)
    calls.each do |call|
      return call if call[0] == name

      result = find_call(call[3], name)
      return result if result
    end
    nil
  end

  def find_all_calls(calls, name, results = [])
    calls.each do |call|
      results << call if call[0] == name
      find_all_calls(call[3], name, results)
    end
    results
  end

  before { element.process }

  describe 'mask element' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <defs>
            <mask id="m1">
              <rect width="200" height="200" fill="white"/>
            </mask>
          </defs>
          <rect width="100" height="100" fill="red" mask="url(#m1)"/>
        </svg>
      SVG
    end

    it 'generates save_graphics_state and soft_mask calls' do
      expect(flattened_calls).to include ['save_graphics_state', [], {}]
      expect(flattened_calls).to include ['soft_mask', [], {}]
    end

    it 'renders the masked element with fill color' do
      expect(flattened_calls).to include ['fill_color', ['ff0000'], {}]
    end
  end

  describe 'display none behavior' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <mask id="m1">
            <rect width="200" height="200" fill="white"/>
          </mask>
          <rect width="100" height="100" fill="red"/>
        </svg>
      SVG
    end

    it 'does not render mask content directly' do
      mask_element = document.elements_by_id['m1']
      expect(mask_element.computed_properties.display).to eq 'none'
    end
  end

  describe 'container behavior' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <mask id="m1">
            <rect width="200" height="200" fill="white"/>
          </mask>
          <rect width="100" height="100" fill="red"/>
        </svg>
      SVG
    end

    it 'acts as a container element' do
      mask_element = document.elements_by_id['m1']
      expect(mask_element).to be_a Prawn::SVG::Elements::Mask
    end
  end

  describe 'missing mask reference' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <rect width="100" height="100" fill="red" mask="url(#nonexistent)"/>
        </svg>
      SVG
    end

    it 'emits a warning' do
      expect(document.warnings).to include 'Could not resolve mask URI to a mask element'
    end
  end

  describe 'mask="none"' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <rect width="100" height="100" fill="red" mask="none"/>
        </svg>
      SVG
    end

    it 'does not emit warnings or soft_mask calls' do
      expect(document.warnings).to be_empty
      expect(flattened_calls).not_to include ['soft_mask', [], {}]
    end
  end

  describe 'maskContentUnits=objectBoundingBox without bounding box' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <defs>
            <mask id="m1" maskContentUnits="objectBoundingBox">
              <rect width="1" height="1" fill="white"/>
            </mask>
          </defs>
          <g mask="url(#m1)"><rect width="100" height="100" fill="red"/></g>
        </svg>
      SVG
    end

    it 'emits a warning about missing bounding box' do
      expect(document.warnings).to include 'mask with maskContentUnits="objectBoundingBox" requires element to have a bounding box'
    end
  end

  describe 'maskUnits=userSpaceOnUse' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <defs>
            <mask id="m1" maskUnits="userSpaceOnUse" x="0" y="0" width="200" height="200">
              <rect width="200" height="200" fill="white"/>
            </mask>
          </defs>
          <rect width="100" height="100" fill="red" mask="url(#m1)"/>
        </svg>
      SVG
    end

    it 'renders the mask with clip region' do
      expect(flattened_calls).to include ['save_graphics_state', [], {}]
      expect(flattened_calls).to include ['soft_mask', [], {}]
      expect(flattened_calls).to include ['clip', [], {}]
    end
  end

  describe 'objectBoundingBox mask region clipping' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <defs>
            <mask id="m1">
              <rect width="200" height="200" fill="white"/>
            </mask>
          </defs>
          <rect x="50" y="50" width="100" height="100" fill="red" mask="url(#m1)"/>
        </svg>
      SVG
    end

    it 'includes a clip call for the mask region' do
      expect(flattened_calls).to include ['clip', [], {}]
    end
  end

  describe 'maskContentUnits=objectBoundingBox with coordinate scaling' do
    let(:svg) do
      <<~SVG
        <svg width="400" height="300">
          <defs>
            <mask id="m1" maskContentUnits="objectBoundingBox">
              <rect width="1" height="1" fill="white"/>
            </mask>
          </defs>
          <rect x="20" y="20" width="150" height="100" fill="red" mask="url(#m1)"/>
        </svg>
      SVG
    end

    it 'scales mask content coordinates to the element bounding box' do
      soft_mask_call = find_call(element.base_calls, 'soft_mask')
      expect(soft_mask_call).not_to be_nil

      # The soft_mask children include a clip rectangle (1.2x expanded) followed by
      # the scaled content. Find rectangles and check the content one (second).
      mask_children = soft_mask_call[3]
      rects = find_all_calls(mask_children, 'rectangle')
      expect(rects.length).to eq 2

      # First rect is the clip region (150 * 1.2 = 180, 100 * 1.2 = 120)
      _, clip_w, clip_h = rects[0][1]
      expect(clip_w).to be_within(0.01).of(180)
      expect(clip_h).to be_within(0.01).of(120)

      # Second rect is the scaled mask content (1.0 * 150 = 150, 1.0 * 100 = 100)
      point, content_w, content_h = rects[1][1]
      expect(content_w).to be_within(0.01).of(150)
      expect(content_h).to be_within(0.01).of(100)
      expect(point[0]).to be_within(0.01).of(20)
    end
  end

  describe 'mask applied to a group' do
    let(:svg) do
      <<~SVG
        <svg width="300" height="300">
          <defs>
            <mask id="m1">
              <rect width="300" height="300" fill="white"/>
            </mask>
          </defs>
          <g mask="url(#m1)">
            <rect width="100" height="100" fill="red"/>
            <rect x="100" y="100" width="100" height="100" fill="blue"/>
          </g>
        </svg>
      SVG
    end

    it 'generates soft_mask around the group contents' do
      expect(flattened_calls).to include ['soft_mask', [], {}]
      expect(flattened_calls).to include ['fill_color', ['ff0000'], {}]
      expect(flattened_calls).to include ['fill_color', ['0000ff'], {}]
    end
  end

  describe 'multiple elements sharing the same mask' do
    let(:svg) do
      <<~SVG
        <svg width="400" height="300">
          <defs>
            <mask id="m1">
              <circle cx="75" cy="75" r="60" fill="white"/>
            </mask>
          </defs>
          <rect x="10" y="10" width="150" height="150" fill="red" mask="url(#m1)"/>
          <rect x="200" y="10" width="150" height="150" fill="blue" mask="url(#m1)"/>
        </svg>
      SVG
    end

    it 'generates separate soft_mask calls for each element' do
      soft_mask_calls = flattened_calls.select { |c| c == ['soft_mask', [], {}] }
      expect(soft_mask_calls.length).to eq 2
    end
  end

  describe 'nested content inside mask' do
    let(:svg) do
      <<~SVG
        <svg width="300" height="300">
          <defs>
            <mask id="m1">
              <g>
                <rect width="300" height="300" fill="white"/>
                <circle cx="150" cy="150" r="50" fill="black"/>
              </g>
            </mask>
          </defs>
          <rect width="300" height="300" fill="red" mask="url(#m1)"/>
        </svg>
      SVG
    end

    it 'includes mask content from nested elements' do
      expect(flattened_calls).to include ['soft_mask', [], {}]
      expect(flattened_calls.any? { |c| c[0] == 'rectangle' }).to be true
      expect(flattened_calls.any? { |c| c[0] == 'circle' }).to be true
    end
  end

  describe 'mask with gradient fill' do
    let(:svg) do
      <<~SVG
        <svg width="300" height="300">
          <defs>
            <linearGradient id="fade" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
            </linearGradient>
            <mask id="m1">
              <rect width="300" height="300" fill="url(#fade)"/>
            </mask>
          </defs>
          <rect width="300" height="300" fill="red" mask="url(#m1)"/>
        </svg>
      SVG
    end

    it 'includes gradient rendering calls in the mask' do
      expect(flattened_calls).to include ['soft_mask', [], {}]
      expect(flattened_calls.any? { |c| c[0] == 'svg:render_gradient' }).to be true
    end
  end

  describe 'maskContentUnits=objectBoundingBox with rounded_rectangle' do
    let(:svg) do
      <<~SVG
        <svg width="400" height="300">
          <defs>
            <mask id="m1" maskContentUnits="objectBoundingBox">
              <rect width="1" height="1" rx="0.1" fill="white"/>
            </mask>
          </defs>
          <rect x="20" y="20" width="150" height="100" fill="red" mask="url(#m1)"/>
        </svg>
      SVG
    end

    it 'scales rounded_rectangle coordinates to the element bounding box' do
      soft_mask_call = find_call(element.base_calls, 'soft_mask')
      expect(soft_mask_call).not_to be_nil

      mask_children = soft_mask_call[3]
      rounded_rects = find_all_calls(mask_children, 'rounded_rectangle')
      expect(rounded_rects.length).to eq 1

      point, width, height, radius = rounded_rects[0][1]
      expect(width).to be_within(0.01).of(150)
      expect(height).to be_within(0.01).of(100)
      expect(radius).to be_within(0.01).of(15)
      expect(point[0]).to be_within(0.01).of(20)
    end
  end

  describe 'maskUnits=userSpaceOnUse default clip coordinates' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <defs>
            <mask id="m1" maskUnits="userSpaceOnUse">
              <rect width="200" height="200" fill="white"/>
            </mask>
          </defs>
          <rect width="100" height="100" fill="red" mask="url(#m1)"/>
        </svg>
      SVG
    end

    it 'uses -10%/120% defaults producing correct Prawn coordinates' do
      soft_mask_call = find_call(element.base_calls, 'soft_mask')
      expect(soft_mask_call).not_to be_nil

      mask_children = soft_mask_call[3]
      rects = find_all_calls(mask_children, 'rectangle')
      clip_rect = rects.first

      point, width, height = clip_rect[1]
      expect(point[0]).to be_within(0.01).of(-20)
      expect(point[1]).to be_within(0.01).of(220)
      expect(width).to be_within(0.01).of(240)
      expect(height).to be_within(0.01).of(240)
    end
  end

  describe 'mask referencing non-mask element' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <defs>
            <rect id="not-a-mask" width="200" height="200" fill="white"/>
          </defs>
          <rect width="100" height="100" fill="red" mask="url(#not-a-mask)"/>
        </svg>
      SVG
    end

    it 'emits a warning' do
      expect(document.warnings).to include 'Could not resolve mask URI to a mask element'
    end
  end
end
