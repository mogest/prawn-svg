require 'spec_helper'

RSpec.describe Prawn::SVG::Attributes::ClipPath do
  let(:font_registry) { Prawn::SVG::FontRegistry.new('Helvetica' => { normal: nil }) }
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], { enable_web_requests: false }, font_registry: font_registry) }
  let(:element) { Prawn::SVG::Elements::Root.new(document, document.root, []) }
  let(:flattened_calls) { flatten_calls(element.base_calls) }

  before { element.process }

  describe 'clip-rule' do
    context 'with default clip-rule (nonzero) and single child' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <defs>
              <clipPath id="c1">
                <circle cx="100" cy="100" r="50"/>
              </clipPath>
            </defs>
            <rect width="200" height="200" fill="red" clip-path="url(#c1)"/>
          </svg>
        SVG
      end

      it 'generates a clip call without clip_rule' do
        clip_call = flattened_calls.detect { |c| c[0] == 'clip' }
        expect(clip_call).to eq ['clip', [], {}]
      end
    end

    context 'with clip-rule="evenodd" on single-child clipPath' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <defs>
              <clipPath id="c1" clip-rule="evenodd">
                <path d="M100,10 L40,198 L190,78 L10,78 L160,198 Z"/>
              </clipPath>
            </defs>
            <rect width="200" height="200" fill="red" clip-path="url(#c1)"/>
          </svg>
        SVG
      end

      it 'generates a clip call with even_odd clip_rule' do
        clip_call = flattened_calls.detect { |c| c[0] == 'clip' }
        expect(clip_call).to eq ['clip', [], { clip_rule: :even_odd }]
      end
    end

    context 'with clip-rule="evenodd" on multi-child clipPath' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <defs>
              <clipPath id="c1" clip-rule="evenodd">
                <circle cx="100" cy="100" r="80"/>
                <circle cx="100" cy="100" r="40"/>
              </clipPath>
            </defs>
            <rect width="200" height="200" fill="red" clip-path="url(#c1)"/>
          </svg>
        SVG
      end

      it 'uses nonzero to preserve correct union semantics' do
        clip_call = flattened_calls.detect { |c| c[0] == 'clip' }
        expect(clip_call).to eq ['clip', [], {}]
      end
    end

    context 'with clip-rule inherited from parent group on single-child clipPath' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <defs>
              <g clip-rule="evenodd">
                <clipPath id="c1">
                  <path d="M100,10 L40,198 L190,78 L10,78 L160,198 Z"/>
                </clipPath>
              </g>
            </defs>
            <rect width="200" height="200" fill="red" clip-path="url(#c1)"/>
          </svg>
        SVG
      end

      it 'inherits evenodd from the parent group' do
        clip_call = flattened_calls.detect { |c| c[0] == 'clip' }
        expect(clip_call).to eq ['clip', [], { clip_rule: :even_odd }]
      end
    end
  end

  describe 'clipPathUnits' do
    context 'with clipPathUnits="userSpaceOnUse" (default)' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <defs>
              <clipPath id="c1">
                <rect x="10" y="10" width="80" height="80"/>
              </clipPath>
            </defs>
            <rect x="0" y="0" width="100" height="100" fill="red" clip-path="url(#c1)"/>
          </svg>
        SVG
      end

      it 'uses the clip path coordinates as-is' do
        rect_call = flattened_calls.detect { |c| c[0] == 'rectangle' }
        expect(rect_call).not_to be_nil
      end
    end

    context 'with clipPathUnits="objectBoundingBox"' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <defs>
              <clipPath id="c1" clipPathUnits="objectBoundingBox">
                <rect x="0" y="0" width="0.5" height="1"/>
              </clipPath>
            </defs>
            <rect x="50" y="50" width="100" height="80" fill="red" clip-path="url(#c1)"/>
          </svg>
        SVG
      end

      it 'scales clip path coordinates to the element bounding box' do
        # The clipped rect is at x=50, y=50, w=100, h=80
        # In Prawn coords: left=50, top=150, right=150, bottom=70
        # The clip rect is x=0..0.5, y=0..1 in objectBoundingBox
        # So it should map to: x=50..100, y=70..150 (left half of the element)
        rect_calls = flattened_calls.select { |c| c[0] == 'rectangle' }
        clip_rect = rect_calls.first
        expect(clip_rect).not_to be_nil
        _, width, height = clip_rect[1]
        expect(width).to be_within(0.01).of(50.0) # 0.5 * 100
        expect(height).to be_within(0.01).of(80.0) # 1.0 * 80
      end
    end

    context 'with clipPathUnits="objectBoundingBox" on element without bounding box' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <defs>
              <clipPath id="c1" clipPathUnits="objectBoundingBox">
                <rect x="0" y="0" width="0.5" height="1"/>
              </clipPath>
            </defs>
            <g clip-path="url(#c1)">
              <rect width="100" height="100" fill="red"/>
            </g>
          </svg>
        SVG
      end

      it 'skips the clip path and adds a warning' do
        expect(document.warnings).to include(
          'clipPath with clipPathUnits="objectBoundingBox" requires element to have a bounding box'
        )
      end
    end

    context 'with clipPathUnits="objectBoundingBox" using a circle' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <defs>
              <clipPath id="c1" clipPathUnits="objectBoundingBox">
                <circle cx="0.5" cy="0.5" r="0.5"/>
              </clipPath>
            </defs>
            <rect x="0" y="0" width="200" height="200" fill="red" clip-path="url(#c1)"/>
          </svg>
        SVG
      end

      it 'scales the circle to the element bounding box' do
        clip_call = flattened_calls.detect { |c| c[0] == 'clip' }
        expect(clip_call).not_to be_nil
      end
    end
  end

  describe 'text in clip paths' do
    context 'with text inside a clipPath' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <defs>
              <clipPath id="textClip">
                <text x="10" y="50" font-size="40">Hello</text>
              </clipPath>
            </defs>
            <rect width="200" height="200" fill="red" clip-path="url(#textClip)"/>
          </svg>
        SVG
      end

      it 'uses a soft_mask instead of a clip call' do
        clip_call = flattened_calls.detect { |c| c[0] == 'clip' }
        expect(clip_call).to be_nil

        mask_call = flattened_calls.detect { |c| c[0] == 'soft_mask' }
        expect(mask_call).not_to be_nil
      end

      it 'generates an svg:render call for the text element' do
        render_call = flattened_calls.detect { |c| c[0] == 'svg:render' }
        expect(render_call).not_to be_nil
      end

      it 'does not produce any warnings' do
        expect(document.warnings).to be_empty
      end
    end

    context 'with text and shapes mixed in a clipPath' do
      let(:svg) do
        <<~SVG
          <svg width="200" height="200">
            <defs>
              <clipPath id="mixedClip">
                <text x="10" y="50" font-size="40">Hello</text>
                <circle cx="100" cy="100" r="50"/>
              </clipPath>
            </defs>
            <rect width="200" height="200" fill="red" clip-path="url(#mixedClip)"/>
          </svg>
        SVG
      end

      it 'uses soft_mask when text is present' do
        clip_call = flattened_calls.detect { |c| c[0] == 'clip' }
        expect(clip_call).to be_nil

        mask_call = flattened_calls.detect { |c| c[0] == 'soft_mask' }
        expect(mask_call).not_to be_nil
      end
    end
  end
end
