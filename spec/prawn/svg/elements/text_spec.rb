require "#{File.dirname(__FILE__)}/../../../spec_helper"

describe Prawn::SVG::Elements::Text do
  let(:document) do
    Prawn::SVG::Document.new(svg, [800, 600], {},
      font_registry: Prawn::SVG::FontRegistry.new('Helvetica' => { normal: nil }, 'Courier' => { normal: nil }, 'Times-Roman' => { normal: nil }))
  end
  let(:element) { Prawn::SVG::Elements::Text.new(document, document.root, [], fake_state) }

  let(:prawn) { Prawn::Document.new(margin: 0) }
  let(:renderer) { Prawn::SVG::Renderer.new(prawn, document, {}) }

  def process_and_render
    element.process
    element.render(prawn, renderer)
  end

  describe 'basic text rendering' do
    let(:svg) { '<text>Hello World</text>' }

    it 'renders simple text' do
      expect(prawn).to receive(:draw_text).with(anything, hash_including(:size, :at)).and_call_original

      process_and_render
    end

    it 'lays out the text during rendering' do
      allow(prawn).to receive(:width_of).and_call_original
      expect(prawn).to receive(:save_font).at_least(:once).and_call_original
      expect(prawn).to receive(:width_of).with('Hello World', hash_including(:kerning)).and_call_original

      process_and_render
    end
  end

  describe 'xml:space preserve' do
    let(:svg) { %(<text#{attributes}>some\n\t  text</text>) }

    context 'when xml:space is preserve' do
      let(:attributes) { ' xml:space="preserve"' }

      it 'converts newlines and tabs to spaces, and preserves spaces' do
        allow(prawn).to receive(:width_of).and_call_original
        allow(prawn).to receive(:draw_text).and_call_original
        expect(prawn).to receive(:width_of).with('some    text', hash_including(:kerning, :size)).and_call_original

        process_and_render
      end
    end

    context 'when xml:space is unspecified' do
      let(:attributes) { '' }

      it 'strips space' do
        allow(prawn).to receive(:width_of).and_call_original
        allow(prawn).to receive(:draw_text).and_call_original
        expect(prawn).to receive(:width_of).with('some text', hash_including(:kerning, :size)).and_call_original

        process_and_render
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
      drawn_texts = []
      allow(prawn).to receive(:draw_text).and_wrap_original do |method, text, **opts|
        drawn_texts << text
        method.call(text, **opts)
      end

      process_and_render

      expect(drawn_texts).to eq ['Some text here ', 'More text', 'Even more', ' leading goodness ', 'ok']
    end
  end

  describe 'when text-anchor is specified' do
    let(:svg) { '<g text-anchor="middle" font-size="12"><text x="50" y="14">Text</text></g>' }
    let(:element) { Prawn::SVG::Elements::Container.new(document, document.root, [], fake_state) }

    it 'should inherit text-anchor from parent element' do
      allow(prawn).to receive(:width_of).and_return(40.0)
      expect(prawn).to receive(:translate).with(-20.0, 0).and_call_original
      expect(prawn).to receive(:draw_text).with(anything, hash_including(:at)).and_call_original

      element.process
      renderer.render_calls(prawn, element.calls)
    end
  end

  describe 'letter-spacing' do
    let(:svg) { '<text letter-spacing="5">spaced</text>' }

    it 'calls character_spacing with the requested size' do
      allow(prawn).to receive(:font).and_call_original
      allow(prawn).to receive(:character_spacing).and_call_original
      expect(prawn).to receive(:font).with('Helvetica', style: :normal).at_least(:once).and_call_original
      expect(prawn).to receive(:character_spacing).with(5.0).at_least(:once).and_call_original
      expect(prawn).to receive(:draw_text).with(anything, hash_including(size: 16, at: anything)).and_call_original

      process_and_render
    end
  end

  describe 'text-decoration' do
    describe 'underline' do
      let(:svg) { '<text text-decoration="underline">underlined</text>' }

      it 'draws an underline' do
        allow(prawn).to receive(:width_of).and_call_original
        expect(prawn).to receive(:draw_text).with(anything, hash_including(:size, :at)).and_call_original
        expect(prawn).to receive(:width_of).with('underlined', hash_including(:kerning, :size)).at_least(:once).and_call_original

        expect(prawn).to receive(:fill_rectangle).with(
          [0, be_within(1).of(598.56)], be_within(0.5).of(75), be_within(0.5).of(0.96)
        ).and_call_original

        process_and_render
      end
    end

    describe 'overline' do
      let(:svg) { '<text text-decoration="overline">overlined</text>' }

      it 'draws an overline above the text' do
        expect(prawn).to receive(:fill_rectangle).with(
          [0, be_within(2).of(616)], be_within(1).of(65), be_within(0.5).of(0.96)
        ).and_call_original

        process_and_render
      end
    end

    describe 'line-through' do
      let(:svg) { '<text text-decoration="line-through">struck</text>' }

      it 'draws a line through the text' do
        expect(prawn).to receive(:fill_rectangle).with(
          [0, be_within(2).of(605)], be_within(0.5).of(43), be_within(0.5).of(0.96)
        ).and_call_original

        process_and_render
      end
    end

    describe 'multiple decorations' do
      let(:svg) { '<text text-decoration="underline line-through">decorated</text>' }

      it 'draws both underline and line-through' do
        expect(prawn).to receive(:fill_rectangle).twice.and_call_original

        process_and_render
      end
    end
  end

  describe 'link' do
    let(:fake_state) do
      state = super()
      state.anchor_href = 'http://example.com'
      state
    end

    let(:svg) { '<text>a link</text>' }

    it 'marks the element to be underlined' do
      expect(prawn).to receive(:link_annotation).with(
        [0.0, 596.688, 37.344, 615.184],
        {
          A:      {
            S:    :URI,
            Type: :Action,
            URI:  'http://example.com'
          },
          Border: [0, 0, 0]
        }
      )

      process_and_render
    end
  end

  describe 'fill/stroke modes' do
    context 'with a stroke and no fill' do
      let(:svg) { '<text stroke="red" fill="none">stroked</text>' }

      it 'calls text_rendering_mode with the requested options' do
        element.process

        calls_flat = flatten_calls(element.calls)
        expect(calls_flat).to include(['stroke_color', ['ff0000'], {}])

        allow(prawn).to receive(:font).and_call_original
        allow(prawn).to receive(:text_rendering_mode).and_call_original
        expect(prawn).to receive(:font).with('Helvetica', style: :normal).at_least(:once).and_call_original
        expect(prawn).to receive(:text_rendering_mode).with(:stroke).at_least(:once).and_call_original
        expect(prawn).to receive(:draw_text).with(anything, hash_including(size: 16, at: anything)).and_call_original

        element.render(prawn, renderer)
      end
    end

    context 'with a mixture of everything' do
      let(:svg) do
        '<text stroke="red" fill="none">stroked <tspan fill="black">both</tspan><tspan stroke="none">neither</tspan></text>'
      end

      it 'calls text_rendering_mode with the requested options' do
        element.process

        calls_flat = flatten_calls(element.calls)
        expect(calls_flat).to include(['stroke_color', ['ff0000'], {}])

        allow(prawn).to receive(:text_rendering_mode).and_call_original
        expect(prawn).to receive(:text_rendering_mode).with(:stroke).at_least(:once).and_call_original
        expect(prawn).to receive(:text_rendering_mode).with(:fill_stroke).at_least(:once).and_call_original
        expect(prawn).to receive(:text_rendering_mode).with(:invisible).at_least(:once).and_call_original
        allow(prawn).to receive(:draw_text).and_call_original
        expect(prawn).to receive(:save_graphics_state).at_least(:once).and_call_original
        expect(prawn).to receive(:restore_graphics_state).at_least(:once).and_call_original

        element.render(prawn, renderer)
      end
    end
  end

  describe 'font finding' do
    context 'with a font that exists' do
      let(:svg) { '<text font-family="monospace">hello</text>' }

      it 'finds the font and uses it' do
        allow(prawn).to receive(:font).and_call_original
        expect(prawn).to receive(:font).with('Courier', style: :normal).at_least(:once).and_call_original
        expect(prawn).to receive(:draw_text).with(anything, hash_including(size: 16, at: anything)).and_call_original

        process_and_render
      end
    end

    context "with a font that doesn't exist" do
      let(:svg) { '<text font-family="does not exist">hello</text>' }

      it 'uses the fallback font' do
        allow(prawn).to receive(:font).and_call_original
        expect(prawn).to receive(:font).with('Times-Roman', style: :normal).at_least(:once).and_call_original
        expect(prawn).to receive(:draw_text).with(anything, hash_including(size: 16, at: anything)).and_call_original

        process_and_render
      end

      context 'when there is no fallback font' do
        before { document.font_registry.installed_fonts.delete('Times-Roman') }

        it "doesn't call the font method and logs a warning" do
          process_and_render

          expect(document.warnings.first).to include 'is not a known font'
        end
      end
    end
  end

  describe 'fallback fonts' do
    before do
      ttf = File.expand_path('../../../sample_ttf/OpenSans-SemiboldItalic.ttf', __dir__)
      prawn.font_families.update('Open Sans' => { normal: ttf })
    end

    let(:document) do
      Prawn::SVG::Document.new(svg, [800, 600], {}, font_registry: Prawn::SVG::FontRegistry.new(prawn.font_families))
    end

    context 'when text contains characters unsupported by the primary built-in font' do
      let(:svg) { "<text font-family=\"sans-serif, 'Open Sans'\">Hello \u0167</text>" }

      it 'uses the fallback font for unsupported characters' do
        drawn = []
        allow(prawn).to receive(:draw_text).and_wrap_original do |method, text, **opts|
          drawn << [text, prawn.font.family]
          method.call(text, **opts)
        end

        process_and_render

        expect(drawn).to include(['Hello ', 'Helvetica'])
        expect(drawn).to include(["\u0167", 'Open Sans'])
      end
    end
  end

  describe '<tref>' do
    let(:svg) { '<svg xmlns:xlink="http://www.w3.org/1999/xlink"><defs><text id="ref" fill="green">my reference text</text></defs><text x="10"><tref xlink:href="#ref" fill="red" /></text></svg>' }
    let(:element) { Prawn::SVG::Elements::Root.new(document, document.root, [], fake_state) }

    it 'references the text' do
      element.process

      expect(element.calls.any? { |call| call[0] == 'svg:render' }).to be true
    end
  end

  describe 'dx and dy attributes' do
    let(:svg) { '<text x="10 20" dx="30 50 80" dy="2">Hi there, this is a good test</text>' }

    it 'correctly calculates the positions of the text' do
      expect(prawn).to receive(:draw_text).with(anything, hash_including(at: [40.0, anything])).and_call_original # 10 + 30
      expect(prawn).to receive(:draw_text).with(anything, hash_including(at: [70.0, anything])).and_call_original # 20 + 50
      allow(prawn).to receive(:draw_text).and_call_original

      process_and_render
    end
  end

  describe 'rotate attribute' do
    let(:svg) { '<text rotate="10 20 30 40 50 60 70 80 90 100">Hi <tspan rotate="0">this</tspan> ok!</text>' }

    it 'correctly processes rotated text' do
      drawn = []
      allow(prawn).to receive(:draw_text).and_wrap_original do |method, text, **opts|
        drawn << [text, opts[:rotate]]
        method.call(text, **opts)
      end

      process_and_render

      expect(drawn).to include(['H', -10.0])
      expect(drawn).to include(['i', -20.0])
      expect(drawn).to include([' ', -30.0])
      expect(drawn).to include(['o', -90.0])
      expect(drawn).to include(['k', -100.0])
      this_entry = drawn.find { |text, _| text == 'this' }
      expect(this_entry[1]).to be_nil
    end
  end

  describe "when there's a comment inside the text element" do
    let(:svg) { '<text>Hi <!-- comment --> there</text>' }

    it 'ignores the comment' do
      expect(renderer).to receive(:render_calls).with(prawn, anything).and_call_original
      expect(prawn).to receive(:width_of).at_least(:once).and_call_original

      process_and_render
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
