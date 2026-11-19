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

    it 'skips the image that references a document containing it and reports an invalid issue' do
      requests, result = render_self_referencing(1)

      expect(requests).to eq 1
      expect(result[:issues].map(&:category)).to eq [:invalid]
      expect(result[:warnings]).to eq ["image tag references '#{url}?1', which contains it"]
    end

    it 'follows each chain of distinct URLs until it repeats, fetching each URL once' do
      requests, result = render_self_referencing(3)

      expect(requests).to eq 3
      expect(result[:warnings].length).to eq 3
    end
  end

  describe 'SVG images nested through endless distinct URLs' do
    it 'stops when elements are nested too deeply' do
      requests = 0
      web_requests = lambda do |uri|
        requests += 1
        %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><image href="https://image-test.invalid/#{uri.path[/\d+/].to_i + 1}.svg" width="10" height="10"/></svg>)
      end
      svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><image href="https://image-test.invalid/0.svg" width="10" height="10"/></svg>)

      result = Prawn::Document.new.svg(svg, web_requests: web_requests)

      expect(result[:warnings]).to eq ['elements are nested too deeply']
      expect(requests).to be < Prawn::SVG::Document::MAX_ELEMENT_DEPTH
    end
  end

  describe 'the same SVG image drawn many times' do
    let(:icon) { "data:image/svg+xml;base64,#{['<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><circle r="4"/></svg>'].pack('m0')}" }

    it 'draws every copy' do
      images = %(<image width="10" height="10" href='#{icon}'/>) * 60
      pdf = Prawn::Document.new

      expect(pdf.svg(%(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">#{images}</svg>))[:warnings]).to be_empty
      expect(pdf.render.scan(" c\n").length).to eq 60 * 4
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

    it 'reports issues from the nested document when parsed, whether or not it is drawn' do
      document = Prawn::SVG::Document.new(svg, [800, 600], options, font_registry: Prawn::SVG::FontRegistry.new(Prawn::Document.new.font_families))
      Prawn::SVG::Elements::Root.new(document, document.root, []).process

      expect(document.warnings).to eq ['Error retrieving URL spec/sample_images/mushroom-wide.jpg: No handler available for this URL scheme']
    end
  end

  describe 'nested SVG font definitions' do
    let(:pdf) { Prawn::Document.new }
    let(:resources) do
      {
        '/child.svg'      => font_svg('Courier', 'child', image_tag('grandchild') + image_tag('inherited')),
        '/grandchild.svg' => font_svg('Times-Roman', 'grandchild'),
        '/inherited.svg'  => font_svg(nil, 'inherited'),
        '/sibling.svg'    => font_svg(nil, 'sibling')
      }
    end
    let(:svg) { font_svg('Helvetica', 'parent', image_tag('child') + image_tag('sibling')) }

    def image_tag(name)
      %(<image href="https://fonts.test/#{name}.svg" width="100" height="100"/>)
    end

    def font_svg(font, label, images = '')
      style = %(<style>@font-face { font-family: Shared; src: local("#{font}"); }</style>) if font
      %(<svg width="100" height="100">#{style}#{images}<text y="50" font-family="Shared">#{label}</text></svg>)
    end

    it 'renders each document with its own definitions and inherits fonts without affecting siblings or parents' do
      rendered_fonts = []
      allow(pdf).to receive(:draw_text).and_wrap_original do |original, text, **options|
        rendered_fonts << [text, pdf.font.name]
        original.call(text, **options)
      end

      families = pdf.font_families.dup
      result = pdf.svg(svg, web_requests: ->(uri) { resources.fetch(uri.path) })

      expect(result[:warnings]).to be_empty
      expect(rendered_fonts).to eq [
        ['grandchild', 'Times-Roman'], ['inherited', 'Courier'], ['child', 'Courier'],
        ['sibling', 'Helvetica'], ['parent', 'Helvetica']
      ]
      expect(pdf.font_families).to eq families
      expect { pdf.render }.not_to raise_error
    end

    it 'restores the parent font definitions if rendering a nested document fails' do
      allow(pdf).to receive(:draw_text).and_raise('render failed')
      families = pdf.font_families.dup

      expect do
        pdf.svg(svg, web_requests: ->(uri) { resources.fetch(uri.path) })
      end.to raise_error('render failed')

      expect(pdf.font_families).to eq families
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

    it 'checks each image once per render, and only decodes it when drawing' do
      allow(Prawn::Images::PNG).to receive(:new).and_call_original
      built = 0
      allow_any_instance_of(Prawn::Images::PNG).to receive(:build_pdf_object).and_wrap_original do |method, *args|
        built += 1
        method.call(*args)
      end
      image = '<image href="https://x.test/i" width="10" height="10"/>'
      svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">#{image * 3}</svg>)
      Prawn::Document.new.svg(svg, web_requests: ->(_uri) { png(0) })

      # Once by prawn-svg, and once by Prawn when it draws the image.
      expect(Prawn::Images::PNG).to have_received(:new).twice
      expect(built).to eq 1
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
