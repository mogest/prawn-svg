require 'spec_helper'

RSpec.describe Prawn::SVG::Attributes::ClipPath do
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], {}) }
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
end
