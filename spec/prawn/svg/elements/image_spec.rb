require 'spec_helper'

describe Prawn::SVG::Elements::Image do
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], options) }
  let(:element) { Prawn::SVG::Elements::Root.new(document, document.root, []) }
  let(:options) { { enable_web_requests: false, enable_file_requests_with_root: '.' } }
  let(:flattened_calls) { flatten_calls(element.base_calls) }

  let(:external_svg) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 200 200">
        <view id="topLeft" viewBox="0 0 100 100"/>
        <view id="bottomRight" viewBox="100 100 100 100"/>
        <view id="customAspect" viewBox="0 0 100 100" preserveAspectRatio="xMinYMin slice"/>
        <rect x="0" y="0" width="100" height="100" fill="red"/>
        <rect x="100" y="100" width="100" height="100" fill="blue"/>
      </svg>
    SVG
  end

  describe 'view element fragment' do
    let(:svg) do
      <<~SVG
        <svg width="400" height="400" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <image xlink:href="http://image-test.invalid/drawing.svg#topLeft" width="200" height="200"/>
        </svg>
      SVG
    end

    before do
      document.url_loader.add_to_cache('http://image-test.invalid/drawing.svg', external_svg)
      element.process
    end

    it 'renders without warnings' do
      expect(document.warnings).to be_empty
    end

    it 'applies the view viewBox to the sub-document' do
      sub_doc_call = flattened_calls.find { |c| c[0] == 'svg:render_sub_document' }
      expect(sub_doc_call).not_to be_nil
      sub_doc = sub_doc_call[1].first
      expect(sub_doc.sizing.viewport_width).to eq 100.0
      expect(sub_doc.sizing.viewport_height).to eq 100.0
    end
  end

  describe 'view element with preserveAspectRatio' do
    let(:svg) do
      <<~SVG
        <svg width="400" height="400" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <image xlink:href="http://image-test.invalid/drawing.svg#customAspect" width="200" height="200"/>
        </svg>
      SVG
    end

    before do
      document.url_loader.add_to_cache('http://image-test.invalid/drawing.svg', external_svg)
      element.process
    end

    it 'renders without warnings' do
      expect(document.warnings).to be_empty
    end
  end

  describe 'svgView() fragment' do
    let(:svg) do
      <<~SVG
        <svg width="400" height="400" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <image xlink:href="http://image-test.invalid/drawing.svg#svgView(viewBox(50,50,100,100))" width="200" height="200"/>
        </svg>
      SVG
    end

    before do
      document.url_loader.add_to_cache('http://image-test.invalid/drawing.svg', external_svg)
      element.process
    end

    it 'renders without warnings' do
      expect(document.warnings).to be_empty
    end

    it 'applies the svgView viewBox to the sub-document' do
      sub_doc_call = flattened_calls.find { |c| c[0] == 'svg:render_sub_document' }
      expect(sub_doc_call).not_to be_nil
      sub_doc = sub_doc_call[1].first
      expect(sub_doc.sizing.viewport_width).to eq 100.0
      expect(sub_doc.sizing.viewport_height).to eq 100.0
      expect(sub_doc.sizing.x_offset).to eq(50.0)
      expect(sub_doc.sizing.y_offset).to eq(50.0)
    end
  end

  describe 'svgView() with preserveAspectRatio' do
    let(:svg) do
      <<~SVG
        <svg width="400" height="400" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <image xlink:href="http://image-test.invalid/drawing.svg#svgView(viewBox(0,0,100,100);preserveAspectRatio(xMinYMin slice))" width="200" height="200"/>
        </svg>
      SVG
    end

    before do
      document.url_loader.add_to_cache('http://image-test.invalid/drawing.svg', external_svg)
      element.process
    end

    it 'renders without warnings' do
      expect(document.warnings).to be_empty
    end
  end

  describe 'fragment referencing non-view element' do
    let(:svg) do
      <<~SVG
        <svg width="400" height="400" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <image xlink:href="http://image-test.invalid/drawing.svg#nonexistent" width="200" height="200"/>
        </svg>
      SVG
    end

    before do
      document.url_loader.add_to_cache('http://image-test.invalid/drawing.svg', external_svg)
      element.process
    end

    it 'renders the full SVG without applying any view override' do
      expect(flattened_calls.any? { |c| c[0] == 'svg:render_sub_document' }).to be true
    end
  end

  describe 'view element in document does not produce warnings' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
          <view id="zoomed" viewBox="0 0 100 100"/>
          <rect width="200" height="200" fill="red"/>
        </svg>
      SVG
    end

    before { element.process }

    it 'renders without warnings' do
      expect(document.warnings).to be_empty
    end
  end

  describe 'URL without fragment' do
    let(:svg) do
      <<~SVG
        <svg width="400" height="400" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <image xlink:href="http://image-test.invalid/drawing.svg" width="200" height="200"/>
        </svg>
      SVG
    end

    before do
      document.url_loader.add_to_cache('http://image-test.invalid/drawing.svg', external_svg)
      element.process
    end

    it 'renders the full SVG normally' do
      expect(flattened_calls.any? { |c| c[0] == 'svg:render_sub_document' }).to be true
    end
  end
end
