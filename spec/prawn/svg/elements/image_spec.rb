require 'spec_helper'

describe Prawn::SVG::Elements::Image do
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], options) }
  let(:element) { Prawn::SVG::Elements::Root.new(document, document.root, []) }
  let(:options) { { enable_file_requests_with_root: '.' } }
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

  describe 'SVG images that reference themselves' do
    let(:url) { 'http://image-test.invalid/self.svg' }

    def render_self_referencing(count)
      requests = 0
      images = (1..count).map { |n| %(<image href="#{url}?#{n}" width="10" height="10"/>) }.join
      self_svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">#{images}</svg>)
      result = Prawn::Document.new.svg(self_svg, web_requests: ->(_uri) { (requests += 1) && self_svg })
      [requests, result]
    end

    it 'stops nesting and reports a resource issue' do
      requests, result = render_self_referencing(1)

      expect(requests).to eq Prawn::SVG::Document::MAX_NESTED_DOCUMENTS + 1
      expect(result[:issues].map(&:category)).to eq [:resource]
      expect(result[:warnings]).to eq ['too many nested SVG documents']
    end

    it 'limits the total number of nested documents when they fan out' do
      requests, = render_self_referencing(6)

      expect(requests).to be <= (Prawn::SVG::Document::MAX_NESTED_DOCUMENTS * 6) + 6
    end
  end

  describe 'nested SVG image' do
    let(:inner_svg) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <image href="spec/sample_images/mushroom-wide.jpg" width="5" height="5"/>
          <text y="5">hello</text>
        </svg>
      SVG
    end
    let(:svg) do
      %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><image href="data:image/svg+xml;base64,#{[inner_svg].pack('m0')}" width="10" height="10"/></svg>)
    end

    it "renders text, but can't load files even when the parent can" do
      result = Prawn::Document.new.svg(svg, enable_file_requests_with_root: '.')

      expect(result[:warnings]).to eq ['Error retrieving URL spec/sample_images/mushroom-wide.jpg: No handler available for this URL scheme']
    end
  end

  describe 'corrupt image data' do
    def png(interlace, size = 1)
      chunk = ->(type, data) { [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N') }
      header = [size, size, 8, 0, 0, 0, interlace].pack('NNC5')
      "\x89PNG\r\n\x1a\n".b + chunk['IHDR', header] + chunk['IDAT', Zlib::Deflate.deflate("\0\0")] + chunk['IEND', '']
    end

    five_channel_jpeg = "\xFF\xD8\xFF\xC0\x00\x11\x08\x00\x01\x00\x01\x05\x01\x11\x00\x02\x11\x00\x03\x11\x00\xFF\xD9".b

    it 'accepts a valid PNG' do
      svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><image href="https://x.test/i" width="10" height="10"/></svg>)
      result = Prawn::Document.new.svg(svg, web_requests: ->(_uri) { png(0) })

      expect(result[:warnings]).to be_empty
    end

    it 'checks each image once per render' do
      allow(Prawn::Images::PNG).to receive(:new).and_call_original
      image = '<image href="https://x.test/i" width="10" height="10"/>'
      svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">#{image * 3}</svg>)
      Prawn::Document.new.svg(svg, web_requests: ->(_uri) { png(0) })

      # Once by prawn-svg, and once by Prawn when it draws the image.
      expect(Prawn::Images::PNG).to have_received(:new).twice
    end

    ["\x89PNG\r\n\x1a\nrubbish".b, "\xFF\xD8\xFFrubbish".b, :interlaced_png, :huge_png, five_channel_jpeg].each do |data|
      it "reports #{data.inspect} as a resource issue" do
        data = png(1) if data == :interlaced_png
        data = png(0, 100_000) if data == :huge_png
        svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><image href="https://x.test/i" width="10" height="10"/></svg>)
        result = Prawn::Document.new.svg(svg, web_requests: ->(_uri) { data })

        expect(result[:issues].map(&:category)).to eq [:resource]
        expect(result[:warnings]).to eq ['image tag references image data which could not be parsed']
      end
    end
  end

  describe 'view fragment in SVG data with oversized entities' do
    let(:svg) do
      %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><image href="https://x.test/e.svg#v" width="10" height="10"/></svg>)
    end

    it 'reports a resource issue' do
      entities = %(<!DOCTYPE svg [<!ENTITY a "#{'x' * 1000}"><!ENTITY b "#{'&a;' * 16}">]>)
      data = %(#{entities}<svg xmlns="http://www.w3.org/2000/svg"><view id="&b;"/></svg>)
      result = Prawn::Document.new.svg(svg, web_requests: ->(_uri) { data })

      expect(result[:warnings]).to eq ['image tag references SVG data which could not be parsed']
    end
  end
end
