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
