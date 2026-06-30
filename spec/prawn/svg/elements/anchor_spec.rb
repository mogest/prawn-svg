require 'spec_helper'

describe Prawn::SVG::Elements::Anchor do
  let(:document) do
    Prawn::SVG::Document.new(svg, [800, 600], {},
      font_registry: Prawn::SVG::FontRegistry.new('Helvetica' => { normal: nil }))
  end
  let(:element) { Prawn::SVG::Elements::Anchor.new(document, document.root.elements.first, [], fake_state) }

  before { element.process }

  context 'with a non-empty href' do
    let(:svg) { '<svg><a href="http://example.com"><rect width="10" height="10"/></a></svg>' }

    it 'sets the anchor_href and adds a link annotation' do
      expect(flatten_calls(element.base_calls).map(&:first)).to include('svg:add_link')
    end
  end

  context 'with an empty href' do
    let(:svg) { '<svg><a href=""><rect width="10" height="10"/></a></svg>' }

    it 'does not add a link annotation' do
      expect(flatten_calls(element.base_calls).map(&:first)).not_to include('svg:add_link')
    end
  end

  context 'with a whitespace-only href' do
    let(:svg) { '<svg><a href="   "><rect width="10" height="10"/></a></svg>' }

    it 'does not add a link annotation' do
      expect(flatten_calls(element.base_calls).map(&:first)).not_to include('svg:add_link')
    end
  end

  context 'with no href' do
    let(:svg) { '<svg><a><rect width="10" height="10"/></a></svg>' }

    it 'does not add a link annotation' do
      expect(flatten_calls(element.base_calls).map(&:first)).not_to include('svg:add_link')
    end
  end
end
