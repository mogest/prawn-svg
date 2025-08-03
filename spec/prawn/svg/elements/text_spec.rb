require "#{File.dirname(__FILE__)}/../../../spec_helper"

describe Prawn::SVG::Elements::Text do
  let(:document) do
    Prawn::SVG::Document.new(svg, [800, 600], {},
      font_registry: Prawn::SVG::FontRegistry.new('Helvetica' => { normal: nil }, 'Courier' => { normal: nil }, 'Times-Roman' => { normal: nil }))
  end
  let(:element) { Prawn::SVG::Elements::Text.new(document, document.root, [], fake_state) }

  let(:default_style) do
    { size: 16, style: :normal, at: [:relative, :relative], offset: [0, 0] }
  end

  let(:prawn) { instance_double('Prawn::Document') }
  let(:renderer) { instance_double('Prawn::SVG::Renderer') }

  def setup_basic_mocks
    allow(prawn).to receive(:save_font).and_yield
    allow(prawn).to receive(:font)
    allow(prawn).to receive(:width_of).and_return(50.0)
    allow(prawn).to receive(:draw_text)
    allow(prawn).to receive(:horizontal_text_scaling).and_yield
    allow(prawn).to receive(:character_spacing) do |spacing = nil, &block|
      if spacing.nil?
        0 # return current character spacing when called without args
      elsif block
        block.call # yield when called with spacing
      end
    end
    allow(prawn).to receive(:text_rendering_mode).and_yield
    allow(prawn).to receive(:translate) do |*_args, &block|
      block&.call
    end
    allow(prawn).to receive(:save_graphics_state)
    allow(prawn).to receive(:restore_graphics_state)
    allow(prawn).to receive(:fill_rectangle)
    allow(prawn).to receive(:fill_color)
    allow(prawn).to receive(:stroke_color)

    # Mock render_calls to actually execute the procs so we can test the real calls
    allow(renderer).to receive(:render_calls) do |prawn_doc, calls|
      calls.each do |call, arguments, kwarguments, children|
        case call
        when 'svg:yield'
          proc = arguments.first
          proc&.call
        when 'svg:render'
          element = arguments.first
          element.render(prawn_doc, renderer) if element.respond_to?(:render)
        else
          if prawn_doc.respond_to?(call) && children.empty?
            prawn_doc.send(call, *arguments, **kwarguments)
          elsif prawn_doc.respond_to?(call) && children.any?
            prawn_doc.send(call, *arguments, **kwarguments) do
              renderer.render_calls(prawn_doc, children)
            end
          end
        end
      end
    end
  end

  def process_and_render
    element.process
    element.render(prawn, renderer)
  end

  describe 'basic text rendering' do
    let(:svg) { '<text>Hello World</text>' }

    it 'renders simple text' do
      setup_basic_mocks
      process_and_render

      expect(prawn).to have_received(:draw_text).with('Hello World', hash_including(:size, :at))
    end

    it 'lays out the text during rendering' do
      setup_basic_mocks
      process_and_render
      expect(prawn).to have_received(:save_font).at_least(:once)
      expect(prawn).to have_received(:width_of).with('Hello World', hash_including(:kerning, :size))
    end
  end

  describe 'xml:space preserve' do
    let(:svg) { %(<text#{attributes}>some\n\t  text</text>) }

    context 'when xml:space is preserve' do
      let(:attributes) { ' xml:space="preserve"' }

      it 'converts newlines and tabs to spaces, and preserves spaces' do
        setup_basic_mocks
        process_and_render

        expect(prawn).to have_received(:draw_text).with('some    text', hash_including(:size, :at))
        expect(prawn).to have_received(:width_of).with('some    text', hash_including(:kerning, :size))
      end
    end

    context 'when xml:space is unspecified' do
      let(:attributes) { '' }

      it 'strips space' do
        setup_basic_mocks
        process_and_render

        expect(prawn).to have_received(:draw_text).with('some text', hash_including(:size, :at))
        expect(prawn).to have_received(:width_of).with('some text', hash_including(:kerning, :size))
      end
    end
  end

  describe 'conventional whitespace handling' do
    let(:svg) do
      <<~SVG
        <text>
          <tspan>
          </tspan>
          Some text here
          <tspan>More text</tspan>
        Even more
        <tspan></tspan>
        <tspan>
          leading goodness
          </tspan>
          ok
              <tspan>
              </tspan>
        </text>
      SVG
    end

    it 'correctly apportions white space between the tags' do
      setup_basic_mocks
      process_and_render

      expect(prawn).to have_received(:draw_text).with('Some text here ', anything)
      expect(prawn).to have_received(:draw_text).with('More text', anything)
      expect(prawn).to have_received(:draw_text).with('Even more', anything)
      expect(prawn).to have_received(:draw_text).with(' leading goodness ', anything)
      expect(prawn).to have_received(:draw_text).with('ok', anything)
    end
  end

  describe 'when text-anchor is specified' do
    let(:svg) { '<g text-anchor="middle" font-size="12"><text x="50" y="14">Text</text></g>' }
    let(:element) { Prawn::SVG::Elements::Container.new(document, document.root, [], fake_state) }

    it 'should inherit text-anchor from parent element' do
      setup_basic_mocks
      allow(prawn).to receive(:width_of).and_return(40.0)

      element.process
      renderer.render_calls(prawn, element.calls)

      expect(prawn).to have_received(:translate).with(-20.0, 0)
      expect(prawn).to have_received(:draw_text).with('Text', anything)
    end
  end

  describe 'letter-spacing' do
    let(:svg) { '<text letter-spacing="5">spaced</text>' }

    it 'calls character_spacing with the requested size' do
      setup_basic_mocks
      process_and_render

      expect(prawn).to have_received(:font).with('Helvetica', style: :normal).at_least(:once)
      expect(prawn).to have_received(:character_spacing).with(5.0)
      expect(prawn).to have_received(:draw_text).with('spaced', hash_including(size: 16, at: anything))
    end
  end

  describe 'underline' do
    let(:svg) { '<text text-decoration="underline">underlined</text>' }

    it 'marks the element to be underlined' do
      setup_basic_mocks
      process_and_render

      expect(prawn).to have_received(:draw_text).with('underlined', hash_including(:size, :at))
      expect(prawn).to have_received(:fill_rectangle).with(
        [0, be_within(1).of(598.56)], 50.0, be_within(0.5).of(0.96)
      )
      expect(prawn).to have_received(:width_of).with('underlined', hash_including(:kerning, :size))
    end
  end

  describe 'fill/stroke modes' do
    context 'with a stroke and no fill' do
      let(:svg) { '<text stroke="red" fill="none">stroked</text>' }

      it 'calls text_rendering_mode with the requested options' do
        setup_basic_mocks

        element.process

        calls_flat = flatten_calls(element.calls)
        expect(calls_flat).to include(['stroke_color', ['ff0000'], {}])

        element.render(prawn, renderer)

        expect(prawn).to have_received(:font).with('Helvetica', style: :normal).at_least(:once)
        expect(prawn).to have_received(:text_rendering_mode).with(:stroke)
        expect(prawn).to have_received(:draw_text).with('stroked', hash_including(size: 16, at: anything))
      end
    end

    context 'with a mixture of everything' do
      let(:svg) do
        '<text stroke="red" fill="none">stroked <tspan fill="black">both</tspan><tspan stroke="none">neither</tspan></text>'
      end

      it 'calls text_rendering_mode with the requested options' do
        setup_basic_mocks

        element.process

        calls_flat = flatten_calls(element.calls)
        expect(calls_flat).to include(['stroke_color', ['ff0000'], {}])

        element.render(prawn, renderer)

        expect(prawn).to have_received(:text_rendering_mode).with(:stroke)
        expect(prawn).to have_received(:text_rendering_mode).with(:fill_stroke)
        expect(prawn).to have_received(:text_rendering_mode).with(:invisible)
        expect(prawn).to have_received(:draw_text).with('stroked ', anything)
        expect(prawn).to have_received(:draw_text).with('both', anything)
        expect(prawn).to have_received(:draw_text).with('neither', anything)
        expect(prawn).to have_received(:save_graphics_state).at_least(:once)
        expect(prawn).to have_received(:restore_graphics_state).at_least(:once)
      end
    end
  end

  describe 'font finding' do
    context 'with a font that exists' do
      let(:svg) { '<text font-family="monospace">hello</text>' }

      it 'finds the font and uses it' do
        setup_basic_mocks
        process_and_render

        expect(prawn).to have_received(:font).with('Courier', style: :normal).at_least(:once)
        expect(prawn).to have_received(:draw_text).with('hello', hash_including(size: 16, at: anything))
      end
    end

    context "with a font that doesn't exist" do
      let(:svg) { '<text font-family="does not exist">hello</text>' }

      it 'uses the fallback font' do
        setup_basic_mocks
        process_and_render

        expect(prawn).to have_received(:font).with('Times-Roman', style: :normal).at_least(:once)
        expect(prawn).to have_received(:draw_text).with('hello', hash_including(size: 16, at: anything))
      end

      context 'when there is no fallback font' do
        before { document.font_registry.installed_fonts.delete('Times-Roman') }

        it "doesn't call the font method and logs a warning" do
          setup_basic_mocks
          process_and_render

          expect(prawn).not_to have_received(:font)
          expect(document.warnings.first).to include 'is not a known font'
        end
      end
    end
  end

  describe '<tref>' do
    let(:svg) { '<svg xmlns:xlink="http://www.w3.org/1999/xlink"><defs><text id="ref" fill="green">my reference text</text></defs><text x="10"><tref xlink:href="#ref" fill="red" /></text></svg>' }
    let(:element) { Prawn::SVG::Elements::Root.new(document, document.root, [], fake_state) }

    it 'references the text' do
      setup_basic_mocks

      element.process

      expect(element.calls.any? { |call| call[0] == 'svg:render' }).to be true
    end
  end

  describe 'dx and dy attributes' do
    let(:svg) { '<text x="10 20" dx="30 50 80" dy="2">Hi there, this is a good test</text>' }

    it 'correctly calculates the positions of the text' do
      setup_basic_mocks
      process_and_render

      expect(prawn).to have_received(:draw_text).with('H', hash_including(at: [40.0, anything])) # 10 + 30
      expect(prawn).to have_received(:draw_text).with('i', hash_including(at: [70.0, anything])) # 20 + 50
      expect(prawn).to have_received(:draw_text).with(' there, this is a good test', anything)
    end
  end

  describe 'rotate attribute' do
    let(:svg) { '<text rotate="10 20 30 40 50 60 70 80 90 100">Hi <tspan rotate="0">this</tspan> ok!</text>' }

    it 'correctly processes rotated text' do
      setup_basic_mocks
      process_and_render

      expect(prawn).to have_received(:draw_text).with('H', hash_including(rotate: -10.0))
      expect(prawn).to have_received(:draw_text).with('i', hash_including(rotate: -20.0))
      expect(prawn).to have_received(:draw_text).with(' ', hash_including(rotate: -30.0))
      expect(prawn).to have_received(:draw_text).with('this', hash_excluding(:rotate))
      expect(prawn).to have_received(:draw_text).with('o', hash_including(rotate: -90.0))
      expect(prawn).to have_received(:draw_text).with('k', hash_including(rotate: -100.0))
    end
  end

  describe "when there's a comment inside the text element" do
    let(:svg) { '<text>Hi <!-- comment --> there</text>' }

    it 'ignores the comment' do
      setup_basic_mocks
      process_and_render

      expect(renderer).to have_received(:render_calls).with(prawn, anything)
      expect(prawn).to have_received(:width_of).at_least(:once)
    end
  end

  describe 'when a use element references a tspan element' do
    let(:svg) do
      <<~SVG
        <svg>
          <defs>
            <text>
              <tspan id="tspan-element">Referenced text</tspan>
            </text>
          </defs>
          <use href="#tspan-element"/>
        </svg>
      SVG
    end
    let(:element) { Prawn::SVG::Elements::Root.new(document, document.root, [], fake_state) }

    it 'emits a warning that tspan cannot be used' do
      element.process
      expect(document.warnings).to include('attempted to <use> a component inside a text element, this is not supported')
    end
  end

  describe 'when a use element references a text element' do
    let(:svg) do
      <<~SVG
        <svg>
          <defs>
            <text id="text-element"><tspan>Referenced text</tspan></text>
          </defs>
          <use href="#text-element"/>
        </svg>
      SVG
    end
    let(:element) { Prawn::SVG::Elements::Root.new(document, document.root, [], fake_state) }

    it 'processes the referenced text element' do
      element.process
      expect(document.warnings).to eq []
      expect(flatten_calls(element.base_calls).map(&:first)).to include 'svg:render'
    end
  end
end
