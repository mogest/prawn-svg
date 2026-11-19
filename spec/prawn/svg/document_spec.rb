require "#{File.dirname(__FILE__)}/../../spec_helper"

describe Prawn::SVG::Document do
  let(:bounds) { [100, 100] }
  let(:options) { {} }

  describe '#initialize' do
    context 'with a well-formed document' do
      let(:svg) { '<svg></svg>' }
      let(:options) { { color_mode: :cmyk } }

      it 'parses the XML and yields itself to its block' do
        yielded = nil

        document = Prawn::SVG::Document.new(svg, bounds, options) do |doc|
          yielded = doc
        end

        expect(yielded).to eq document
        expect(document.color_mode).to eq :cmyk
        expect(document.root.name).to eq 'svg'
      end
    end

    describe 'web requests' do
      let(:url) { 'https://example.com/image.png' }

      def load_with(options)
        Prawn::SVG::Document.new('<svg></svg>', bounds, options).url_loader.load(url)
      end

      it 'are disabled by default' do
        expect { load_with({}) }.to raise_error Prawn::SVG::UrlLoader::Error, /web requests are disabled/
      end

      it 'are made through the callable given as web_requests' do
        expect(load_with(web_requests: ->(uri) { "fetched #{uri}" })).to eq "fetched #{url}"
      end

      it 'are enabled by the legacy enable_web_requests option' do
        expect(load_with(enable_web_requests: ->(_uri) { 'data' })).to eq 'data'
      end

      it 'are made through ssrf_filter when the legacy enable_web_requests option is true' do
        expect(SsrfFilter).to receive(:get) { |*, &block| http_response(Net::HTTPOK, body: 'data').tap(&block) }
        expect(load_with(enable_web_requests: true)).to eq 'data'
      end

      it 'are disabled when web_requests is false or nil, even if enable_web_requests is true' do
        expect { load_with(web_requests: false, enable_web_requests: true) }.to raise_error Prawn::SVG::UrlLoader::Error, /web requests are disabled/
        expect { load_with(web_requests: nil, enable_web_requests: true) }.to raise_error Prawn::SVG::UrlLoader::Error, /web requests are disabled/
      end

      it 'are enabled when web_requests is true, even if enable_web_requests is false' do
        expect(SsrfFilter).to receive(:get) { |*, &block| http_response(Net::HTTPOK, body: 'data').tap(&block) }
        expect(load_with(web_requests: true, enable_web_requests: false)).to eq 'data'
      end

      it 'raise an ArgumentError for an invalid web_requests value' do
        expect { load_with(web_requests: 'yes') }.to raise_error ArgumentError, /:web_requests must be/
      end
    end

    describe '#replicate' do
      let(:web_requests) { ->(_uri) { 'data' } }
      let(:font_registry) { Prawn::SVG::FontRegistry.new({}) }
      let(:parent) do
        Prawn::SVG::Document.new('<svg></svg>', bounds, { web_requests: web_requests, enable_file_requests_with_root: '.', color_mode: :cmyk }, font_registry: font_registry)
      end
      let(:child) { parent.replicate('<svg></svg>', 10, 20) }

      it "inherits the parent's options and fonts in a separate registry" do
        expect(child.url_loader.load('https://example.com/image.png')).to eq 'data'
        expect(child.color_mode).to eq :cmyk
        expect(child.font_registry).not_to be font_registry
        expect(child.font_registry.installed_fonts).to eq font_registry.installed_fonts
      end

      it "doesn't inherit file access" do
        expect(child.url_loader.loaders).not_to include(an_instance_of(Prawn::SVG::Loaders::File))
      end

      it 'shares the root document' do
        expect(child.replicate('<svg></svg>', 10, 20).root_document).to be parent
      end
    end

    describe 'work budget' do
      let(:parent) { Prawn::SVG::Document.new('<svg></svg>', bounds, { max_work: 300 }) }

      it 'raises once the work budget is exhausted, sharing it with nested documents and charging for them' do
        parent.work_budget.record(46)
        child = parent.replicate('<svg></svg>', 10, 20)
        child.work_budget.record(4)

        expect { child.work_budget.record(1) }.to raise_error Prawn::SVG::Document::WorkLimitExceeded
      end

      it 'never raises when max_work is false' do
        document = Prawn::SVG::Document.new('<svg></svg>', bounds, { max_work: false })

        expect { document.work_budget.record(10**12) }.not_to raise_error
      end

      it 'rejects an invalid max_work' do
        [nil, true, 0, 1.5].each do |max_work|
          expect { Prawn::SVG::Document.new('<svg></svg>', bounds, { max_work: max_work }) }.to raise_error ArgumentError, /:max_work/
        end
      end

      it 'charges requests for URLs even when they fail' do
        document = Prawn::SVG::Document.new('<svg></svg>', bounds, { max_work: 1500, web_requests: ->(_uri) { raise Prawn::SVG::UrlLoader::Error, 'no' } })

        expect { document.resource_loader.load('https://example.com/a.png') }.to raise_error Prawn::SVG::UrlLoader::Error
        expect { document.resource_loader.load('https://example.com/a.png') }.to raise_error Prawn::SVG::Document::WorkLimitExceeded
      end
    end

    context 'when unparsable XML is provided' do
      let(:svg) { "this isn't SVG data" }

      it "raises an exception, passing on REXML's error message" do
        expect do
          Prawn::SVG::Document.new(svg, bounds, options)
        end.to raise_error Prawn::SVG::Document::InvalidSVGData,
          /\AThe data supplied is not a valid SVG document.+Malformed.+#{Regexp.escape(svg)}/m
      end
    end

    context 'when entities expand too far' do
      let(:svg) do
        entities = %(<!ENTITY a "#{'x' * 1000}"><!ENTITY b "#{'&a;' * 16}">)
        %(<!DOCTYPE svg [#{entities}]><svg><text>&b;</text></svg>)
      end

      it 'raises an exception when the document is loaded' do
        expect { Prawn::SVG::Document.new(svg, bounds, options) }.to raise_error Prawn::SVG::Document::InvalidSVGData, /entity expansion/
      end
    end

    context 'when many references to a large entity expand to too much text in total' do
      let(:svg) do
        %(<!DOCTYPE svg [<!ENTITY a "#{'x' * 10_000}">]><svg>#{'<text a="&a;">&a;</text>' * 600}</svg>)
      end

      it 'raises an exception when the document is loaded' do
        expect { Prawn::SVG::Document.new(svg, bounds, options) }.to raise_error Prawn::SVG::Document::InvalidSVGData, /too much text/
      end
    end

    context 'when entities in nested documents expand to too much text in total' do
      def render_images(count)
        nested = %(<!DOCTYPE svg [<!ENTITY a "#{'x' * 10_000}">]><svg xmlns="http://www.w3.org/2000/svg">#{'<g a="&a;"/>' * 200}</svg>)
        image = %(<image width="1" height="1" href="data:image/svg+xml;base64,#{[nested].pack('m0')}"/>)
        Prawn::Document.new.svg(%(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">#{image * count}</svg>))
      end

      it 'stops parsing them once the budget for the render is spent' do
        expect(render_images(4)[:warnings]).not_to include(/could not be parsed/)
        expect(render_images(6)[:warnings]).to include 'image tag references SVG data which could not be parsed'
      end
    end

    context 'when elements are nested too deeply' do
      let(:svg) { "<svg>#{'<g>' * 5000}#{'</g>' * 5000}</svg>" }

      it 'raises an exception when the document is loaded' do
        expect { Prawn::SVG::Document.new(svg, bounds, options) }.to raise_error Prawn::SVG::Document::InvalidSVGData, /nested too deeply/
      end
    end

    context 'when small entities are used' do
      let(:svg) { %(<!DOCTYPE svg [<!ENTITY ns "http://www.w3.org/2000/svg">]><svg xmlns="&ns;"></svg>) }

      it 'expands them' do
        expect(Prawn::SVG::Document.new(svg, bounds, options).root.namespace).to eq 'http://www.w3.org/2000/svg'
      end
    end

    context 'when broken XML is provided' do
      let(:svg) { '<svg><g><rect></rect></svg>' }

      it "raises an exception, passing on REXML's error message" do
        expect do
          Prawn::SVG::Document.new(svg, bounds, options)
        end.to raise_error Prawn::SVG::Document::InvalidSVGData,
          /\AThe data supplied is not a valid SVG document.+Missing end tag for 'g'/m
      end
    end

    context 'when the data is a UTF-16 string without a byte order mark' do
      let(:svg) { '<svg width="5" height="5"></svg>'.encode('UTF-16BE') }

      it 'parses it' do
        expect(Prawn::SVG::Document.new(svg, bounds, options).sizing.output_width).to eq 5
      end
    end

    context 'when the data is invalid UTF-16' do
      let(:svg) { (+"\xD8\x00").force_encoding('UTF-16BE') }

      it 'raises an exception' do
        expect { Prawn::SVG::Document.new(svg, bounds, options) }.to raise_error Prawn::SVG::Document::InvalidSVGData
      end
    end

    context 'when binary data with a UTF-16 byte order mark is provided' do
      let(:svg) { (+"\xFF\xFE").b }

      it 'raises an exception' do
        expect { Prawn::SVG::Document.new(svg, bounds, options) }.to raise_error Prawn::SVG::Document::InvalidSVGData
      end
    end

    context 'with @font-face rules' do
      let(:sample_ttf_dir) { File.expand_path('../../sample_ttf', __dir__) }
      let(:font_filename) { 'OpenSans-SemiboldItalic.ttf' }
      let(:font_path) { File.join(sample_ttf_dir, font_filename) }
      let(:file_options) { { enable_file_requests_with_root: sample_ttf_dir } }

      it 'registers @font-face fonts with the font registry' do
        svg = <<~SVG
          <svg>
            <style>
              @font-face {
                font-family: "TestFont";
                src: url("#{font_path}");
                font-weight: bold;
                font-style: italic;
              }
            </style>
          </svg>
        SVG

        font_registry = Prawn::SVG::FontRegistry.new({})
        Prawn::SVG::Document.new(svg, bounds, file_options, font_registry: font_registry)

        expect(font_registry.installed_fonts['TestFont']).to be_a(Hash)
        expect(font_registry.installed_fonts['TestFont'][:bold_italic]).to be_a(StringIO)
      end

      it 'skips unsupported font formats' do
        svg = <<~SVG
          <svg>
            <style>
              @font-face {
                font-family: "WoffFont";
                src: url("font.woff2") format("woff2");
              }
            </style>
          </svg>
        SVG

        font_registry = Prawn::SVG::FontRegistry.new({})
        Prawn::SVG::Document.new(svg, bounds, options, font_registry: font_registry)

        expect(font_registry.installed_fonts['WoffFont']).to be_nil
      end

      it 'tries multiple sources and uses the first successful one' do
        svg = <<~SVG
          <svg>
            <style>
              @font-face {
                font-family: "MultiFont";
                src: url("nonexistent.ttf"), url("#{font_path}");
              }
            </style>
          </svg>
        SVG

        font_registry = Prawn::SVG::FontRegistry.new({})
        document = Prawn::SVG::Document.new(svg, bounds, file_options, font_registry: font_registry)

        expect(font_registry.installed_fonts['MultiFont']).to be_a(Hash)
        expect(font_registry.installed_fonts['MultiFont'][:normal]).to be_a(StringIO)
        expect(document.warnings).to include(/Failed to load.*nonexistent\.ttf/)
      end

      it 'supports local() font references' do
        svg = <<~SVG
          <svg>
            <style>
              @font-face {
                font-family: "AliasFont";
                src: local("ExistingFont");
                font-weight: bold;
              }
            </style>
          </svg>
        SVG

        font_registry = Prawn::SVG::FontRegistry.new({
          'ExistingFont' => { normal: '/path/to/existing.ttf', bold: '/path/to/bold.ttf' }
        })
        Prawn::SVG::Document.new(svg, bounds, options, font_registry: font_registry)

        expect(font_registry.installed_fonts['AliasFont']).to be_a(Hash)
        expect(font_registry.installed_fonts['AliasFont'][:bold]).to eq('/path/to/bold.ttf')
      end

      it 'does not load file URLs when enable_file_requests_with_root is not set' do
        svg = <<~SVG
          <svg>
            <style>
              @font-face {
                font-family: "FileFont";
                src: url("#{font_path}");
              }
            </style>
          </svg>
        SVG

        font_registry = Prawn::SVG::FontRegistry.new({})
        document = Prawn::SVG::Document.new(svg, bounds, {}, font_registry: font_registry)

        expect(font_registry.installed_fonts['FileFont']).to be_nil
        expect(document.warnings).to include(/Failed to load/)
      end

      it 'does not load web URLs by default' do
        svg = <<~SVG
          <svg>
            <style>
              @font-face {
                font-family: "WebFont";
                src: url("https://example.com/font.ttf");
              }
            </style>
          </svg>
        SVG

        font_registry = Prawn::SVG::FontRegistry.new({})
        document = Prawn::SVG::Document.new(svg, bounds, {}, font_registry: font_registry)

        expect(font_registry.installed_fonts['WebFont']).to be_nil
        expect(document.warnings).to include(/Failed to load/)
      end

      it 'skips @font-face rules without font-family' do
        svg = <<~SVG
          <svg>
            <style>
              @font-face {
                src: url("font.ttf");
              }
            </style>
          </svg>
        SVG

        font_registry = Prawn::SVG::FontRegistry.new({})
        Prawn::SVG::Document.new(svg, bounds, options, font_registry: font_registry)
        expect(font_registry.installed_fonts).not_to have_key(nil)
      end
    end

    context 'with @import rules' do
      let(:sample_css_dir) { File.expand_path('../../sample_css', __dir__) }

      def svg_with_import(url)
        <<~SVG
          <svg>
            <style>
              @import url("#{url}");
              rect { fill: red; }
            </style>
            <rect width="1" height="1" />
          </svg>
        SVG
      end

      it 'loads @import CSS from files when enable_file_requests_with_root is set' do
        css_path = File.join(sample_css_dir, 'import_nested.css')
        document = Prawn::SVG::Document.new(
          svg_with_import(css_path), bounds,
          { enable_file_requests_with_root: sample_css_dir }
        )

        expect(document.warnings).to be_empty
      end

      it 'does not load @import file URLs when enable_file_requests_with_root is not set' do
        css_path = File.join(sample_css_dir, 'import_nested.css')
        document = Prawn::SVG::Document.new(svg_with_import(css_path), bounds, {})

        expect(document.warnings).to include(/Failed to load @import CSS.*No handler available/)
      end

      it 'does not load @import files outside the root path' do
        other_dir = File.expand_path('../../sample_ttf', __dir__)
        css_path = File.join(sample_css_dir, 'import_nested.css')
        document = Prawn::SVG::Document.new(
          svg_with_import(css_path), bounds,
          { enable_file_requests_with_root: other_dir }
        )

        expect(document.warnings).to include(/Failed to load @import CSS.*not inside the root path/)
      end

      it 'does not load @import web URLs by default' do
        expect(Net::HTTP).not_to receive(:new)

        document = Prawn::SVG::Document.new(
          svg_with_import('https://invalid.test/styles.css'), bounds, {}
        )

        expect(document.warnings).to include(/Failed to load @import CSS.*web requests are disabled/)
      end
    end

    context 'when the user passes in a filename instead of SVG data' do
      let(:svg) { 'some_file.svg' }

      it "raises an exception letting them know what they've done" do
        message = "The data supplied is not a valid SVG document.  It looks like you've supplied a filename " \
                  'instead; use File.read(filename) to get the data from the file before you pass it to prawn-svg.'

        expect do
          Prawn::SVG::Document.new(svg, bounds, options)
        end.to raise_error Prawn::SVG::Document::InvalidSVGData, /\A#{Regexp.escape(message)}/
      end
    end
  end

  describe '#find_raw_element_by_id' do
    let(:svg) { '<svg><g id="a"><rect id="b"/></g><rect id="a"/><circle id="c"/></svg>' }

    it 'finds the first element in document order with the id' do
      document = Prawn::SVG::Document.new(svg, bounds, options)

      expect(document.find_raw_element_by_id('a').name).to eq 'g'
      expect(document.find_raw_element_by_id('b').name).to eq 'rect'
      expect(document.find_raw_element_by_id('c').name).to eq 'circle'
      expect(document.find_raw_element_by_id('d')).to be_nil
    end
  end

  describe '#add_issue' do
    subject { Prawn::SVG::Document.new('<svg></svg>', bounds, options) }

    it 'records each distinct issue once' do
      subject.add_issue(:unknown, 'a')
      subject.add_issue(:unknown, 'a')
      subject.add_issue(:unsupported, 'a')
      expect(subject.issues).to eq [Prawn::SVG::Issue.new(:unknown, 'a'), Prawn::SVG::Issue.new(:unsupported, 'a')]
    end
  end
end
