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
  describe 'conditional attributes outside a switch' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <rect requiredFeatures="http://www.w3.org/TR/SVG11/feature#Shape" width="10" height="10" fill="red"/>
          <g requiredFeatures="http://www.w3.org/TR/SVG11/feature#Filter"><rect width="10" height="10" fill="blue"/></g>
          <rect systemLanguage="fr" width="10" height="10" fill="green"/>
          <rect requiredExtensions="http://example.org/ext1" width="10" height="10" fill="yellow"/>
          <use systemLanguage="fr" href="missing.svg#x"/>
          <defs requiredFeatures="http://www.w3.org/TR/SVG11/feature#Filter"><linearGradient id="g"><stop offset="0" stop-color="purple"/></linearGradient></defs>
          <rect width="10" height="10" fill="url(#g)"/>
        </svg>
      SVG
    end

    it 'renders only the elements whose conditions pass, without reporting issues' do
      expect(flattened_calls).to include ['fill_color', ['ff0000'], {}]
      expect(flattened_calls).not_to include ['fill_color', ['0000ff'], {}]
      expect(flattened_calls).not_to include ['fill_color', ['008000'], {}]
      expect(flattened_calls).not_to include ['fill_color', ['ffff00'], {}]
      expect(document.issues).to be_empty
    end

    it 'still allows failing elements to be referenced' do
      expect(flattened_calls.map(&:first)).to include 'svg:render_gradient'
    end
  end

  describe 'referencing failing clip paths, masks and markers' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <clipPath id="c" systemLanguage="fr"><rect width="10" height="10"/></clipPath>
          <mask id="m" systemLanguage="fr"><rect width="10" height="10" fill="white"/></mask>
          <g systemLanguage="fr"><marker id="k"><rect width="1" height="1" fill="blue"/></marker></g>
          <rect width="100" height="100" clip-path="url(#c)" mask="url(#m)"/>
          <path d="M0 0L10 10" marker-end="url(#k)"/>
        </svg>
      SVG
    end

    it 'uses them without reporting issues' do
      expect(flattened_calls.map(&:first)).to include 'clip', 'soft_mask'
      expect(flattened_calls).to include ['fill_color', ['0000ff'], {}]
      expect(document.issues).to be_empty
    end
  end

  describe 'conditional attributes on text content' do
    let(:document) do
      Prawn::SVG::Document.new(svg, [800, 600], options, font_registry: Prawn::SVG::FontRegistry.new(Prawn::Document.new.font_families))
    end
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <path id="p" d="M0 50L100 50"/>
          <text>A<tspan systemLanguage="fr">B</tspan>C<textPath href="#p" requiredExtensions="x">D</textPath>E</text>
        </svg>
      SVG
    end

    it 'renders only the text whose conditions pass' do
      pdf = Prawn::Document.new
      drawn = []
      allow(pdf).to receive(:draw_text).and_wrap_original do |method, text, **opts|
        drawn << text
        method.call(text, **opts)
      end

      pdf.svg(svg)

      expect(drawn.join).to eq 'ACE'
    end
  end

  describe 'conditional attributes on elements that SVG 1.1 does not give them' do
    let(:svg) { '<svg width="200" height="200"><symbol id="s" systemLanguage="fr"><rect width="10" height="10" fill="red"/></symbol><use href="#s"/></svg>' }

    it 'ignores them and reports them as unknown' do
      expect(flattened_calls).to include ['fill_color', ['ff0000'], {}]
      expect(document.issues).to eq [Prawn::SVG::Issue.new(category: :unknown, message: "Unknown attribute 'systemLanguage' on <symbol>")]
    end
  end

  describe 'a failing root element' do
    let(:svg) { '<svg width="200" height="200" systemLanguage="fr"><rect width="10" height="10" fill="red"/></svg>' }

    it 'renders nothing' do
      expect(Prawn::Document.new.tap { |pdf| pdf.svg(svg) }.render).not_to include ' re'
    end
  end

  describe 'a clipPath with children that draw nothing' do
    let(:svg) do
      <<~SVG
        <svg width="200" height="200">
          <clipPath id="c" clip-rule="evenodd" transform="scale(2)">
            <title>t</title>
            <path d="M0 0H50V50H0Z M10 10H40V40H10Z"/>
            <rect systemLanguage="fr" width="1" height="1"/>
            <rect display="none" width="1" height="1"/>
          </clipPath>
          <rect width="100" height="100" clip-path="url(#c)"/>
        </svg>
      SVG
    end

    it 'treats the clipPath as having a single child' do
      expect(flattened_calls).to include ['clip', [], { clip_rule: :even_odd }]
    end
  end
end
