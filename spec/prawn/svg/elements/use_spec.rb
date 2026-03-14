require 'spec_helper'

describe Prawn::SVG::Elements::Use do
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], options) }
  let(:element) { Prawn::SVG::Elements::Root.new(document, document.root, []) }
  let(:options) { { enable_web_requests: false } }
  let(:flattened_calls) { flatten_calls(element.base_calls) }

  describe 'local references' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <defs>
            <rect id="r1" width="50" height="50" fill="red"/>
          </defs>
          <use xlink:href="#r1" x="10" y="10"/>
        </svg>
      SVG
    end

    before { element.process }

    it 'renders the referenced element' do
      expect(flattened_calls).to include ['fill_color', ['ff0000'], {}]
    end

    it 'applies the x/y translation' do
      expect(flattened_calls).to include ['translate', [10.0, -10.0], {}]
    end
  end

  describe 'local reference to symbol' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <defs>
            <symbol id="s1" viewBox="0 0 100 100">
              <rect width="100" height="100" fill="blue"/>
            </symbol>
          </defs>
          <use xlink:href="#s1" width="50" height="50"/>
        </svg>
      SVG
    end

    before { element.process }

    it 'renders the symbol as a viewport' do
      expect(flattened_calls).to include ['fill_color', ['0000ff'], {}]
    end
  end

  describe 'missing local reference' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <use xlink:href="#nonexistent"/>
        </svg>
      SVG
    end

    before { element.process }

    it 'emits a warning' do
      expect(document.warnings.any? { |w| w.include?('nonexistent') }).to be true
    end
  end

  describe 'missing href' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
          <use/>
        </svg>
      SVG
    end

    before { element.process }

    it 'emits a warning about missing href' do
      expect(document.warnings).to include 'use tag must have an href or xlink:href'
    end
  end

  describe 'external references' do
    let(:external_svg) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <style>
            .external-styled { fill: green; }
          </style>
          <defs>
            <rect id="ext-rect" class="external-styled" width="80" height="80"/>
            <symbol id="ext-symbol" viewBox="0 0 100 100">
              <circle cx="50" cy="50" r="40" fill="blue"/>
            </symbol>
          </defs>
          <g id="ext-group">
            <rect width="30" height="30" fill="orange"/>
            <circle cx="50" cy="50" r="20" fill="purple"/>
          </g>
        </svg>
      SVG
    end

    describe 'referencing an element from an external SVG' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <use xlink:href="http://use-test.invalid/icons.svg#ext-rect"/>
          </svg>
        SVG
      end

      before do
        document.url_loader.add_to_cache('http://use-test.invalid/icons.svg', external_svg)
        element.process
      end

      it 'renders the external element' do
        expect(document.warnings).to be_empty
        expect(flattened_calls.any? { |c| c[0] == 'rectangle' }).to be true
      end

      it 'applies CSS styles from the external document' do
        expect(flattened_calls).to include ['fill_color', ['008000'], {}]
      end
    end

    describe 'referencing a symbol from an external SVG' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <use xlink:href="http://use-test.invalid/icons.svg#ext-symbol" width="80" height="80"/>
          </svg>
        SVG
      end

      before do
        document.url_loader.add_to_cache('http://use-test.invalid/icons.svg', external_svg)
        element.process
      end

      it 'renders the external symbol as a viewport' do
        expect(document.warnings).to be_empty
        expect(flattened_calls.any? { |c| c[0] == 'circle' }).to be true
      end
    end

    describe 'referencing a group from an external SVG' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <use xlink:href="http://use-test.invalid/icons.svg#ext-group" x="20" y="20"/>
          </svg>
        SVG
      end

      before do
        document.url_loader.add_to_cache('http://use-test.invalid/icons.svg', external_svg)
        element.process
      end

      it 'renders all children of the external group' do
        expect(document.warnings).to be_empty
        expect(flattened_calls.any? { |c| c[0] == 'rectangle' }).to be true
        expect(flattened_calls.any? { |c| c[0] == 'circle' }).to be true
      end

      it 'applies the x/y translation' do
        expect(flattened_calls).to include ['translate', [20.0, -20.0], {}]
      end
    end

    describe 'external href without fragment identifier' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <use xlink:href="http://use-test.invalid/icons.svg"/>
          </svg>
        SVG
      end

      before do
        document.url_loader.add_to_cache('http://use-test.invalid/icons.svg', external_svg)
        element.process
      end

      it 'emits a warning about missing fragment' do
        expect(document.warnings.any? { |w| w.include?('fragment') }).to be true
      end
    end

    describe 'external href with nonexistent element ID' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <use xlink:href="http://use-test.invalid/icons.svg#nonexistent"/>
          </svg>
        SVG
      end

      before do
        document.url_loader.add_to_cache('http://use-test.invalid/icons.svg', external_svg)
        element.process
      end

      it 'emits a warning' do
        expect(document.warnings.any? { |w| w.include?('nonexistent') }).to be true
      end
    end

    describe 'external href with unreachable URL' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <use xlink:href="http://use-test.invalid/missing.svg#something"/>
          </svg>
        SVG
      end

      before { element.process }

      it 'emits a warning about load failure' do
        expect(document.warnings.any? { |w| w.include?('could not load') }).to be true
      end
    end

    describe 'caching external SVG documents' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <use xlink:href="http://use-test.invalid/icons.svg#ext-rect" x="0" y="0"/>
            <use xlink:href="http://use-test.invalid/icons.svg#ext-group" x="100" y="0"/>
          </svg>
        SVG
      end

      before do
        document.url_loader.add_to_cache('http://use-test.invalid/icons.svg', external_svg)
        element.process
      end

      it 'caches the parsed external document' do
        expect(document.external_svg_cache).to have_key('http://use-test.invalid/icons.svg')
      end

      it 'renders both elements without errors' do
        expect(document.warnings).to be_empty
        expect(flattened_calls.select { |c| c[0] == 'rectangle' }.length).to be >= 2
      end
    end

    describe 'using href attribute instead of xlink:href' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
            <use href="http://use-test.invalid/icons.svg#ext-rect"/>
          </svg>
        SVG
      end

      before do
        document.url_loader.add_to_cache('http://use-test.invalid/icons.svg', external_svg)
        element.process
      end

      it 'renders the external element' do
        expect(document.warnings).to be_empty
        expect(flattened_calls.any? { |c| c[0] == 'rectangle' }).to be true
      end
    end
  end
end
