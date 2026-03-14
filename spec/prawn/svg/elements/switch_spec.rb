require 'spec_helper'

describe Prawn::SVG::Elements::Switch do
  let(:options) { {} }
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], options) }
  let(:element) { Prawn::SVG::Elements::Root.new(document, document.root, []) }
  let(:flattened_calls) { flatten_calls(element.base_calls) }

  before { element.process }

  describe 'renders only the first matching child' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <switch>
            <rect width="100" height="100" fill="red"/>
            <circle cx="50" cy="50" r="50" fill="blue"/>
          </switch>
        </svg>
      SVG
    end

    it 'renders the first child and skips the second' do
      expect(flattened_calls).to include ['fill_color', ['ff0000'], {}]
      expect(flattened_calls).not_to include ['fill_color', ['0000ff'], {}]
    end
  end

  describe 'requiredFeatures' do
    context 'with a supported feature' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <switch>
              <rect requiredFeatures="http://www.w3.org/TR/SVG11/feature#Shape" width="100" height="100" fill="red"/>
              <circle cx="50" cy="50" r="50" fill="blue"/>
            </switch>
          </svg>
        SVG
      end

      it 'renders the element with the supported feature' do
        expect(flattened_calls).to include ['fill_color', ['ff0000'], {}]
        expect(flattened_calls).not_to include ['fill_color', ['0000ff'], {}]
      end
    end

    context 'with an unsupported feature' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <switch>
              <rect requiredFeatures="http://www.w3.org/TR/SVG11/feature#Filter" width="100" height="100" fill="red"/>
              <circle cx="50" cy="50" r="50" fill="blue"/>
            </switch>
          </svg>
        SVG
      end

      it 'skips the element and renders the fallback' do
        expect(flattened_calls).not_to include ['fill_color', ['ff0000'], {}]
        expect(flattened_calls).to include ['fill_color', ['0000ff'], {}]
      end
    end

    context 'with multiple features, one unsupported' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <switch>
              <rect requiredFeatures="http://www.w3.org/TR/SVG11/feature#Shape http://www.w3.org/TR/SVG11/feature#Filter" width="100" height="100" fill="red"/>
              <circle cx="50" cy="50" r="50" fill="blue"/>
            </switch>
          </svg>
        SVG
      end

      it 'skips the element because all features must be supported' do
        expect(flattened_calls).not_to include ['fill_color', ['ff0000'], {}]
        expect(flattened_calls).to include ['fill_color', ['0000ff'], {}]
      end
    end

    context 'with an empty requiredFeatures attribute' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <switch>
              <rect requiredFeatures="" width="100" height="100" fill="red"/>
              <circle cx="50" cy="50" r="50" fill="blue"/>
            </switch>
          </svg>
        SVG
      end

      it 'evaluates to false and skips the element' do
        expect(flattened_calls).not_to include ['fill_color', ['ff0000'], {}]
        expect(flattened_calls).to include ['fill_color', ['0000ff'], {}]
      end
    end
  end

  describe 'requiredExtensions' do
    context 'with any extension specified' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <switch>
              <rect requiredExtensions="http://example.org/extension" width="100" height="100" fill="red"/>
              <circle cx="50" cy="50" r="50" fill="blue"/>
            </switch>
          </svg>
        SVG
      end

      it 'evaluates to false since no extensions are supported' do
        expect(flattened_calls).not_to include ['fill_color', ['ff0000'], {}]
        expect(flattened_calls).to include ['fill_color', ['0000ff'], {}]
      end
    end
  end

  describe 'systemLanguage' do
    context 'with matching language' do
      let(:options) { { language: 'en' } }
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <switch>
              <rect systemLanguage="en" width="100" height="100" fill="red"/>
              <circle cx="50" cy="50" r="50" fill="blue"/>
            </switch>
          </svg>
        SVG
      end

      it 'renders the element with the matching language' do
        expect(flattened_calls).to include ['fill_color', ['ff0000'], {}]
        expect(flattened_calls).not_to include ['fill_color', ['0000ff'], {}]
      end
    end

    context 'with non-matching language' do
      let(:options) { { language: 'fr' } }
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <switch>
              <rect systemLanguage="en" width="100" height="100" fill="red"/>
              <circle cx="50" cy="50" r="50" fill="blue"/>
            </switch>
          </svg>
        SVG
      end

      it 'skips the element and renders the fallback' do
        expect(flattened_calls).not_to include ['fill_color', ['ff0000'], {}]
        expect(flattened_calls).to include ['fill_color', ['0000ff'], {}]
      end
    end

    context 'with prefix matching' do
      let(:options) { { language: 'en' } }
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <switch>
              <rect systemLanguage="en-GB" width="100" height="100" fill="red"/>
              <circle cx="50" cy="50" r="50" fill="blue"/>
            </switch>
          </svg>
        SVG
      end

      it 'matches when user language is a prefix of the element language' do
        expect(flattened_calls).to include ['fill_color', ['ff0000'], {}]
        expect(flattened_calls).not_to include ['fill_color', ['0000ff'], {}]
      end
    end

    context 'with multiple languages in comma-separated list' do
      let(:options) { { language: 'fr' } }
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <switch>
              <rect systemLanguage="en, fr" width="100" height="100" fill="red"/>
              <circle cx="50" cy="50" r="50" fill="blue"/>
            </switch>
          </svg>
        SVG
      end

      it 'matches if any language in the list matches' do
        expect(flattened_calls).to include ['fill_color', ['ff0000'], {}]
        expect(flattened_calls).not_to include ['fill_color', ['0000ff'], {}]
      end
    end

    context 'defaults to en when no language option provided' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <switch>
              <rect systemLanguage="en" width="100" height="100" fill="red"/>
              <circle cx="50" cy="50" r="50" fill="blue"/>
            </switch>
          </svg>
        SVG
      end

      it 'uses en as the default language' do
        expect(flattened_calls).to include ['fill_color', ['ff0000'], {}]
        expect(flattened_calls).not_to include ['fill_color', ['0000ff'], {}]
      end
    end

    context 'with empty systemLanguage attribute' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <switch>
              <rect systemLanguage="" width="100" height="100" fill="red"/>
              <circle cx="50" cy="50" r="50" fill="blue"/>
            </switch>
          </svg>
        SVG
      end

      it 'evaluates to false' do
        expect(flattened_calls).not_to include ['fill_color', ['ff0000'], {}]
        expect(flattened_calls).to include ['fill_color', ['0000ff'], {}]
      end
    end
  end

  describe 'fallback with no conditional attributes' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <switch>
            <rect requiredFeatures="http://www.w3.org/TR/SVG11/feature#Filter" width="100" height="100" fill="red"/>
            <circle cx="50" cy="50" r="50" fill="blue"/>
          </switch>
        </svg>
      SVG
    end

    it 'renders the fallback element that has no conditional attributes' do
      expect(flattened_calls).not_to include ['fill_color', ['ff0000'], {}]
      expect(flattened_calls).to include ['fill_color', ['0000ff'], {}]
    end
  end

  describe 'no matching children' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <switch>
            <rect requiredExtensions="http://example.org/ext1" width="100" height="100" fill="red"/>
            <circle requiredExtensions="http://example.org/ext2" cx="50" cy="50" r="50" fill="blue"/>
          </switch>
        </svg>
      SVG
    end

    it 'renders nothing' do
      expect(flattened_calls).not_to include ['fill_color', ['ff0000'], {}]
      expect(flattened_calls).not_to include ['fill_color', ['0000ff'], {}]
    end
  end

  describe 'switch with group child' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <switch>
            <g>
              <rect width="100" height="100" fill="red"/>
              <circle cx="50" cy="50" r="50" fill="blue"/>
            </g>
          </switch>
        </svg>
      SVG
    end

    it 'renders the entire group subtree' do
      expect(flattened_calls).to include ['fill_color', ['ff0000'], {}]
      expect(flattened_calls).to include ['fill_color', ['0000ff'], {}]
    end
  end

  describe 'case-insensitive language matching' do
    let(:options) { { language: 'EN' } }
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <switch>
            <rect systemLanguage="en" width="100" height="100" fill="red"/>
            <circle cx="50" cy="50" r="50" fill="blue"/>
          </switch>
        </svg>
      SVG
    end

    it 'matches case-insensitively' do
      expect(flattened_calls).to include ['fill_color', ['ff0000'], {}]
    end
  end
end
