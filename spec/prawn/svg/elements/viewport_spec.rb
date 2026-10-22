require 'spec_helper'

describe Prawn::SVG::Elements::Viewport do
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], { enable_web_requests: false }) }
  let(:element) { Prawn::SVG::Elements::Root.new(document, document.root, []) }

  [
    '<svg viewBox="0 0 0 10"><rect width="5" height="5"/></svg>',
    '<svg width="0"><circle r="10%"/></svg>',
    '<symbol id="s"><rect width="5" height="5"/></symbol><use href="#s" width="0"/>'
  ].each do |content|
    context "with zero size: #{content}" do
      let(:svg) { %(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">#{content}</svg>) }

      it 'renders nothing' do
        element.process
        expect(flatten_calls(element.base_calls).map(&:first)).not_to include('rectangle', 'move_to', 'curve_to')
        expect(document.issues).to be_empty
      end
    end
  end

  ['width="-10"', 'viewBox="0 0 -1 5"'].each do |size|
    context "with a negative size: #{size}" do
      let(:svg) { %(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><svg #{size}><rect width="5" height="5"/></svg></svg>) }

      it 'reports it once and renders nothing' do
        element.process
        expect(flatten_calls(element.base_calls).map(&:first)).not_to include('rectangle')
        expect(document.issues).to eq [Prawn::SVG::Issue.new(:invalid, 'Invalid attributes on tag svg; skipping tag')]
      end
    end
  end
end
