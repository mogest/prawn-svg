require 'spec_helper'

describe Prawn::SVG::Elements::Base do
  let(:svg) { '<svg></svg>' }
  let(:document) do
    Prawn::SVG::Document.new(svg, [800, 600], { enable_web_requests: false },
      font_registry: Prawn::SVG::FontRegistry.new('Helvetica' => { normal: nil }))
  end
  let(:parent_calls) { [] }
  let(:element) { Prawn::SVG::Elements::Base.new(document, document.root, parent_calls, fake_state) }

  describe '#initialize' do
    let(:svg) { '<something id="hello"/>' }

    it 'adds itself to the elements_by_id hash if an id attribute is supplied' do
      element
      expect(document.elements_by_id['hello']).to eq element
    end
  end

  describe '#process' do
    it 'calls #parse and #apply so subclasses can parse the element' do
      expect(element).to receive(:parse).ordered
      expect(element).to receive(:apply).ordered
      element.process
    end

    describe 'applying calls from the standard attributes' do
      let(:svg) do
        <<-SVG
          <something transform="scale(2)" fill-opacity="0.5" fill="red" stroke="blue" stroke-width="5"/>
        SVG
      end

      it 'appends the relevant calls' do
        element.process
        expect(element.base_calls).to eq [
          ['transformation_matrix', [2, 0, 0, 2, 0, 0], {}, [
            ['transparent', [0.5, 1], {}, [
              ['fill_color', ['ff0000'], {}, []],
              ['stroke_color', ['0000ff'], {}, []],
              ['line_width', [5.0], {}, []],
              ['fill_and_stroke', [], {}, []]
            ]]
          ]]
        ]
      end
    end

    describe 'fills and strokes' do
      before { element.process }
      subject { element.base_calls.last }

      context 'with neither fill nor stroke' do
        let(:svg) { '<rect style="fill: none;"></rect>' }
        it        { is_expected.to eq ['end_path', [], {}, []] }
      end

      context 'with a fill only' do
        let(:svg) { '<rect style="fill: black;"></rect>' }
        it        { is_expected.to eq ['fill', [], {}, []] }
      end

      context 'with a stroke only' do
        let(:svg) { '<rect style="fill: none; stroke: black;"></rect>' }
        it        { is_expected.to eq ['stroke', [], {}, []] }
      end

      context 'with fill and stroke' do
        let(:svg) { '<rect style="fill: black; stroke: black;"></rect>' }
        it        { is_expected.to eq ['fill_and_stroke', [], {}, []] }
      end

      context 'with fill with evenodd fill rule' do
        let(:svg) { '<rect style="fill: black; fill-rule: evenodd;"></rect>' }
        it        { is_expected.to eq ['fill', [], { fill_rule: :even_odd }, []] }
      end
    end

    it 'appends calls to the parent element' do
      expect(element).to receive(:apply) do
        element.send :add_call, 'test', 'argument', kw: 'argument'
      end

      element.process
      expect(element.parent_calls).to eq [['fill', [], {}, [['test', ['argument'], { kw: 'argument' }, []]]]]
    end

    it 'quietly absorbs a SkipElementQuietly exception' do
      expect(element).to receive(:parse).and_raise(Prawn::SVG::Elements::Base::SkipElementQuietly)
      expect(element).to_not receive(:apply)
      element.process
      expect(document.warnings).to be_empty
    end

    it 'absorbs a SkipElementError exception, logging a warning' do
      expect(element).to receive(:parse).and_raise(Prawn::SVG::Elements::Base::SkipElementError, 'hello')
      expect(element).to_not receive(:apply)
      element.process
      expect(document.issues).to eq [Prawn::SVG::Issue.new(:invalid, 'hello')]
    end

    it 'records the category of a SkipElementError' do
      expect(element).to receive(:parse).and_raise(Prawn::SVG::Elements::Base::SkipElementError.new('hello', :unsupported))
      element.process
      expect(document.issues).to eq [Prawn::SVG::Issue.new(:unsupported, 'hello')]
    end
  end

  describe '#apply_colors' do
    before do
      element.send(:extract_attributes_and_properties)
    end

    subject { element.send :apply_colors }

    it "doesn't change anything if no fill attribute provided" do
      expect(element).to_not receive(:add_call)
      subject
    end

    it "doesn't change anything if 'inherit' fill attribute provided" do
      element.properties.fill = 'inherit'
      expect(element).to_not receive(:add_call)
      subject
    end

    it "doesn't change anything if 'none' fill attribute provided" do
      element.properties.fill = Prawn::SVG::Paint.parse('none')
      expect(element).to_not receive(:add_call)
      subject
    end

    it "uses the fill attribute's color" do
      expect(element).to receive(:add_call).with('fill_color', 'ff0000')
      element.properties.fill = Prawn::SVG::Paint.parse('red')
      subject
    end

    it "ignores the instruction if the fill attribute's color is unparseable" do
      element.properties.fill = Prawn::SVG::Paint.parse('blarble')
      expect(element).to_not receive(:add_call)
      subject
    end

    it "uses the color attribute if 'currentColor' fill attribute provided" do
      element.properties.fill = Prawn::SVG::Paint.parse('currentColor')
      element.state.computed_properties.color = Prawn::SVG::Color::RGB.new('ff0000')
      expect(element).to receive(:add_call).with('fill_color', 'ff0000')
      subject
    end

    context 'with a color attribute defined on a parent element' do
      let(:svg) do
        '<svg style="color: green;"><g style="color: red;"><rect width="10" height="10" style="fill: currentColor;"></rect></g></svg>'
      end
      let(:element) { Prawn::SVG::Elements::Root.new(document, document.root, parent_calls) }
      let(:flattened_calls) { flatten_calls(element.base_calls) }

      it "uses the parent's color element if 'currentColor' fill attribute provided" do
        element.process

        expect(flattened_calls).to include ['fill_color', ['ff0000'], {}]
        expect(flattened_calls).not_to include ['fill_color', ['00ff00'], {}]
      end
    end

    it 'specifies no color if the URL is unresolvable' do
      expect(element).to_not receive(:add_call)
      element.properties.fill = Prawn::SVG::Paint.parse('url(bad)')
      subject
    end
  end

  describe 'stylesheets' do
    let(:svg) { <<-SVG }
      <svg>
        <style>
          .special rect { fill: green; }
          rect { fill: red; }
        </style>
        <rect width="100" height="100"></rect>
        <g class="special">
          <rect width="100" fill="blue" height="100"></rect>
          <rect width="100" height="100" fill="blue" style="fill: yellow;"></rect>
        </g>
      </svg>
    SVG

    it 'applies stylesheet styling but style attributes take precedence' do
      document = Prawn::SVG::Document.new(svg, [100, 100], { enable_web_requests: false })
      calls = []
      element = Prawn::SVG::Elements::Root.new(document, document.root, calls)
      element.process

      fill_colors = calls.select { |cmd, _, _| cmd == 'fill_color' }.map { |_, args, _| args.first }
      expect(fill_colors).to eq ['000000', 'ff0000', '008000', 'ffff00']
    end
  end

  describe 'zero and negative sizes' do
    let(:svg) do
      '<svg><rect width="0" height="10"/><circle r="0"/><ellipse rx="5" ry="0"/><rect width="-1" height="10"/></svg>'
    end

    it 'skips zero-sized shapes quietly, and reports negative sizes' do
      Prawn::SVG::Elements::Root.new(document, document.root, []).process
      expect(document.issues).to eq [Prawn::SVG::Issue.new(:invalid, 'Invalid attributes on tag rect; skipping tag')]
    end
  end

  describe 'inline styles' do
    let(:svg) { <<-SVG }
      <svg>
        <style>rect { fill: red !important; }</style>
        <rect width="10" height="10" style=" Fill : blue ;stroke:green !important;stroke: red"></rect>
      </svg>
    SVG

    it 'parses declarations with whitespace and !important' do
      rect = Prawn::SVG::Elements::Base.new(document, document.root.elements['rect'], [], fake_state)
      rect.process
      expect(document.issues).to be_empty
      expect(rect.properties.fill).to eq Prawn::SVG::Paint.parse('red')
      expect(rect.properties.stroke).to eq Prawn::SVG::Paint.parse('green')
    end

    it 'splits declarations on semicolons outside quotes and brackets, skipping empty ones' do
      expect(element.send(:parse_css_declarations, %{;; : x; fill:; mask: url("a;b"); clip-path: url(data:x;y); font: 12px 'A;B' ! IMPORTANT})).to eq [
        ['fill', '', false],
        ['mask', 'url("a;b")', false],
        ['clip-path', 'url(data:x;y)', false],
        ['font', "12px 'A;B'", true]
      ]
    end
  end

  describe 'attribute issues' do
    let(:svg) { <<-SVG }
      <svg xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape">
        <rect width="10" height="10" pathLength="5" zIndex="1" r="2" data-x="1" inkscape:label="a" onclick="x()"
          role="img" version="1.1" aria-label="x" filter="url(#f)" vector-effect="none" clip="auto" systemLanguage="en"
          Width="5" mix-blend-mode="multiply"></rect>
        <switch><rect width="10" height="10" systemLanguage="en"></rect></switch>
        <text x="0" y="10" zIndex="1"><tspan transform="scale(2)">hello</tspan><textPath side="right">x</textPath></text>
      </svg>
    SVG
    let(:document) do
      Prawn::SVG::Document.new(svg, [800, 600], { enable_web_requests: false },
        font_registry: Prawn::SVG::FontRegistry.new(Prawn::Document.new.font_families))
    end

    it 'adds unsupported and unknown issues, ignoring attributes with no effect' do
      Prawn::SVG::Elements::Root.new(document, document.root, []).process

      expect(document.issues).to eq [
        Prawn::SVG::Issue.new(:unsupported, "Unsupported attribute 'pathLength' on <rect>"),
        Prawn::SVG::Issue.new(:unknown, "Unknown attribute 'zIndex' on <rect>"),
        Prawn::SVG::Issue.new(:unknown, "Unknown attribute 'r' on <rect>"),
        Prawn::SVG::Issue.new(:unsupported, "Unsupported property 'filter' on <rect>"),
        Prawn::SVG::Issue.new(:unsupported, "Unsupported attribute 'systemLanguage' on <rect>"),
        Prawn::SVG::Issue.new(:unknown, "Unknown attribute 'Width' on <rect>"),
        Prawn::SVG::Issue.new(:unknown, "Unknown attribute 'mix-blend-mode' on <rect>"),
        Prawn::SVG::Issue.new(:unknown, "Unknown attribute 'zIndex' on <text>"),
        Prawn::SVG::Issue.new(:unknown, "Unknown attribute 'transform' on <tspan>"),
        Prawn::SVG::Issue.new(:unsupported, "Unsupported attribute 'side' on <textPath>"),
        Prawn::SVG::Issue.new(:invalid, '<textPath> must reference a path element')
      ]
    end
  end

  describe 'attribute value issues' do
    let(:svg) { <<-SVG }
      <svg>
        <rect x="2no" y="1e1" width="10" height="calc(1px)" rx="auto"></rect>
        <linearGradient id="g" gradientUnits="userspaceonuse" spreadMethod="pad"><stop offset="0" stop-color="red"/></linearGradient>
        <text x="1 2 x" y="5"><tspan dx="1,2" rotate="45deg">hi</tspan></text>
      </svg>
    SVG
    let(:document) do
      Prawn::SVG::Document.new(svg, [800, 600], { enable_web_requests: false },
        font_registry: Prawn::SVG::FontRegistry.new(Prawn::Document.new.font_families))
    end

    it 'adds an issue for each value that prawn-svg cannot use' do
      Prawn::SVG::Elements::Root.new(document, document.root, []).process

      expect(document.issues.map(&:message)).to eq [
        "Unsupported value '2no' for attribute 'x' on <rect>",
        "Unsupported value 'calc(1px)' for attribute 'height' on <rect>",
        "Unsupported value 'auto' for attribute 'rx' on <rect>",
        "Unsupported value 'userspaceonuse' for attribute 'gradientUnits' on <linearGradient>",
        "Unsupported value '1 2 x' for attribute 'x' on <text>",
        "Unsupported value '45deg' for attribute 'rotate' on <tspan>"
      ]
      expect(document.issues.map(&:category).uniq).to eq [:unsupported]
    end
  end

  describe 'property issues' do
    let(:svg) { <<-SVG }
      <svg>
        <style>
          rect { filter: blur(2px); stroke: nope; cursor: pointer; -webkit-font-smoothing: auto; }
        </style>
        <rect width="100" height="100" fill="gren" stroke-linecap="round" data-x="1" style="paint-order: stroke; fill-opacity: lots; --var: 1; pointer-events: none; zindex: 1"></rect>
        <title style="paint-order: stroke"></title>
      </svg>
    SVG

    it 'adds an issue for each unsupported property or value, except ones that have no effect or are vendor-prefixed' do
      Prawn::SVG::Elements::Root.new(document, document.root, []).process

      expect(document.issues).to eq [
        Prawn::SVG::Issue.new(:unsupported, "Unsupported value 'gren' for property 'fill' on <rect>"),
        Prawn::SVG::Issue.new(:unsupported, "Unsupported property 'filter' on <rect>"),
        Prawn::SVG::Issue.new(:unsupported, "Unsupported value 'nope' for property 'stroke' on <rect>"),
        Prawn::SVG::Issue.new(:unsupported, "Unsupported property 'paint-order' on <rect>"),
        Prawn::SVG::Issue.new(:unsupported, "Unsupported value 'lots' for property 'fill-opacity' on <rect>"),
        Prawn::SVG::Issue.new(:unknown, "Unknown property 'zindex' on <rect>")
      ]
    end

    context 'on a text element' do
      let(:svg) { '<svg><text style="paint-order: stroke">hello</text></svg>' }
      let(:document) do
        Prawn::SVG::Document.new(svg, [800, 600], { enable_web_requests: false },
          font_registry: Prawn::SVG::FontRegistry.new(Prawn::Document.new.font_families))
      end

      it 'adds the issue once' do
        Prawn::SVG::Elements::Root.new(document, document.root, []).process
        expect(document.issues).to eq [Prawn::SVG::Issue.new(:unsupported, "Unsupported property 'paint-order' on <text>")]
      end
    end

    it 'does not treat a presentation attribute with a rejected value as a plain attribute' do
      rect = Prawn::SVG::Elements::Base.new(document, document.root.elements['rect'], [], fake_state)
      rect.process
      expect(rect.attributes.keys).to eq ['width', 'height', 'data-x', 'style']
    end
  end
end
