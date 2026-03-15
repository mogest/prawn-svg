require 'spec_helper'

describe Prawn::SVG::Elements::TextPath do
  let(:document) do
    Prawn::SVG::Document.new(svg, [800, 600], { enable_web_requests: false },
      font_registry: Prawn::SVG::FontRegistry.new('Helvetica' => { normal: nil }, 'Times-Roman' => { normal: nil }))
  end
  let(:element) { Prawn::SVG::Elements::Text.new(document, document.root.elements[2], [], fake_state) }

  let(:prawn) { Prawn::Document.new(margin: 0) }
  let(:renderer) { Prawn::SVG::Renderer.new(prawn, document, {}) }

  def process_and_render
    # Process the defs first to register elements_by_id
    defs = Prawn::SVG::Elements::Container.new(document, document.root.elements[1], [], fake_state)
    defs.process

    element.process
    element.render(prawn, renderer)
  end

  describe 'text along a straight horizontal path' do
    let(:svg) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <defs><path id="mypath" d="M 10,50 L 310,50"/></defs>
          <text font-size="16"><textPath href="#mypath">Hello</textPath></text>
        </svg>
      SVG
    end

    it 'renders characters along the path' do
      drawn = []
      allow(prawn).to receive(:draw_text).and_wrap_original do |method, text, **opts|
        drawn << [text, opts[:at], opts[:rotate]]
        method.call(text, **opts)
      end

      process_and_render

      expect(drawn).not_to be_empty
      expect(drawn.map(&:first).join).to eq 'Hello'

      drawn.each do |_text, at, rotate|
        expect(at[1]).to be_within(20).of(550)
        expect(rotate).to be_within(0.1).of(0)
      end
    end
  end

  describe 'with startOffset' do
    let(:svg) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <defs><path id="mypath" d="M 0,50 L 300,50"/></defs>
          <text font-size="16"><textPath href="#mypath" startOffset="50">Hi</textPath></text>
        </svg>
      SVG
    end

    it 'starts text at the offset distance' do
      drawn = []
      allow(prawn).to receive(:draw_text).and_wrap_original do |method, text, **opts|
        drawn << [text, opts[:at]]
        method.call(text, **opts)
      end

      process_and_render

      expect(drawn).not_to be_empty
      # First character should start at approximately x=50 + half char width
      expect(drawn.first[1][0]).to be > 40
    end
  end

  describe 'with percentage startOffset' do
    let(:svg) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <defs><path id="mypath" d="M 0,50 L 200,50"/></defs>
          <text font-size="16"><textPath href="#mypath" startOffset="50%">A</textPath></text>
        </svg>
      SVG
    end

    it 'starts at the percentage of path length' do
      drawn = []
      allow(prawn).to receive(:draw_text).and_wrap_original do |method, text, **opts|
        drawn << [text, opts[:at]]
        method.call(text, **opts)
      end

      process_and_render

      expect(drawn).not_to be_empty
      # 50% of 200 = 100, so first char midpoint at ~100
      expect(drawn.first[1][0]).to be_within(20).of(100)
    end
  end

  describe 'when referenced path does not exist' do
    let(:svg) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg">
          <defs></defs>
          <text font-size="16"><textPath href="#nonexistent">Hello</textPath></text>
        </svg>
      SVG
    end

    it 'warns and skips' do
      process_and_render
      expect(document.warnings).to include(match(/not a path element/))
    end
  end

  describe 'when href is missing' do
    let(:svg) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg">
          <defs></defs>
          <text font-size="16"><textPath>Hello</textPath></text>
        </svg>
      SVG
    end

    it 'warns and skips' do
      process_and_render
      expect(document.warnings).to include(match(/must reference/))
    end
  end

  describe 'characters past path end' do
    let(:svg) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <defs><path id="mypath" d="M 0,50 L 30,50"/></defs>
          <text font-size="16"><textPath href="#mypath">Hello World this is a long text</textPath></text>
        </svg>
      SVG
    end

    it 'stops rendering when past path end' do
      drawn = []
      allow(prawn).to receive(:draw_text).and_wrap_original do |method, text, **opts|
        drawn << text
        method.call(text, **opts)
      end

      process_and_render

      # Should render fewer characters than the full text
      rendered_text = drawn.join
      expect(rendered_text.length).to be < 'Hello World this is a long text'.length
    end
  end

  describe 'text along a curved path' do
    let(:svg) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <defs><path id="mypath" d="M 0,100 C 50,0 150,0 200,100"/></defs>
          <text font-size="12"><textPath href="#mypath">Curved</textPath></text>
        </svg>
      SVG
    end

    it 'renders characters with varying angles' do
      drawn = []
      allow(prawn).to receive(:draw_text).and_wrap_original do |method, text, **opts|
        drawn << [text, opts[:rotate]]
        method.call(text, **opts)
      end

      process_and_render

      expect(drawn).not_to be_empty
      # Characters along a curve should have different rotation angles
      angles = drawn.map { |_, r| r }.compact
      expect(angles.uniq.length).to be > 1 if angles.length > 1
    end
  end
end
