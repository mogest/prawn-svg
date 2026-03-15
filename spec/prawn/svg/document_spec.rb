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

    context 'when unparsable XML is provided' do
      let(:svg) { "this isn't SVG data" }

      it "raises an exception, passing on REXML's error message" do
        expect do
          Prawn::SVG::Document.new(svg, bounds, options)
        end.to raise_error Prawn::SVG::Document::InvalidSVGData,
          /\AThe data supplied is not a valid SVG document.+Malformed.+#{Regexp.escape(svg)}/m
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
        expect(font_registry.installed_fonts['TestFont'][:bold_italic]).to be_a(String)
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
        expect(font_registry.installed_fonts['MultiFont'][:normal]).to be_a(String)
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

      it 'does not load web URLs when enable_web_requests is false' do
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
        document = Prawn::SVG::Document.new(svg, bounds, { enable_web_requests: false }, font_registry: font_registry)

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

      it 'does not load @import web URLs when enable_web_requests is false' do
        expect(Net::HTTP).not_to receive(:new)

        document = Prawn::SVG::Document.new(
          svg_with_import('https://invalid.test/styles.css'), bounds,
          { enable_web_requests: false }
        )

        expect(document.warnings).to include(/Failed to load @import CSS.*No handler available/)
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
end
