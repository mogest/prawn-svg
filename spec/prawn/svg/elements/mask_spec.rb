require 'spec_helper'

describe Prawn::SVG::Elements::Mask do
  let(:document) { Prawn::SVG::Document.new(svg, [100, 100], {}) }
  let(:element) { Prawn::SVG::Elements::Mask.new(document, mask_element, [], Prawn::SVG::State.new) }

  describe 'basic mask support' do
    let(:svg) do
      <<-SVG
        <svg xmlns="http://www.w3.org/2000/svg">
          <defs>
            <mask id="circleMask">
              <circle cx="50" cy="50" r="40" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="blue" mask="url(#circleMask)"/>
        </svg>
      SVG
    end

    let(:mask_element) { document.root.elements['//mask'] }

    it 'creates a mask element' do
      expect(element).to be_a(Prawn::SVG::Elements::Mask)
    end

    it 'is a container element' do
      expect(element.container?).to be true
    end

    it 'does not isolate children' do
      expect(element.isolate_children?).to be false
    end
  end

  describe 'mask with use element' do
    let(:svg) do
      <<-SVG
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">
          <defs>
            <circle id="testCircle" cx="25" cy="25" r="20" fill="white"/>
            <mask id="useMask">
              <use xlink:href="#testCircle" x="0" y="0"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" mask="url(#useMask)"/>
        </svg>
      SVG
    end

    let(:mask_element) { document.root.elements['//mask'] }

    it 'can parse masks with use elements' do
      element.parse
      expect(element).to be_a(Prawn::SVG::Elements::Mask)
    end
  end

  describe 'mask processing' do
    let(:svg) do
      <<-SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <mask id="simpleMask">
              <circle cx="50" cy="50" r="40" fill="white"/>
            </mask>
          </defs>
        </svg>
      SVG
    end

    let(:mask_element) { document.root.elements['//mask'] }

    it 'can be parsed' do
      expect { element.parse }.not_to raise_error
      expect(element.mask_units).to eq('objectBoundingBox')
      expect(element.mask_content_units).to eq('userSpaceOnUse')
    end
  end
end