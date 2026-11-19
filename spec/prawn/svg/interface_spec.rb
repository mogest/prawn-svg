require 'spec_helper'

describe Prawn::SVG::Interface do
  let(:bounds) { double(width: 800, height: 600, absolute_left: 0, absolute_top: 0) }
  let(:prawn)  { instance_double(Prawn::Document, font_families: {}, bounds: bounds, cursor: 600) }
  let(:svg)    { '<svg width="250" height="100"></svg>' }

  describe '#initialize' do
    describe 'invalid option detection' do
      it 'rejects unknown options' do
        expect do
          Prawn::SVG::Interface.new(svg, prawn, invalid: 'option', at: [0, 0])
        end.to raise_error(ArgumentError, 'Unknown options: :invalid')
      end

      it 'accepts a single raise_on_issue category' do
        expect do
          Prawn::SVG::Interface.new(svg, prawn, raise_on_issue: :unsupported)
        end.not_to raise_error
      end

      it 'rejects unknown raise_on_issue categories' do
        expect do
          Prawn::SVG::Interface.new(svg, prawn, raise_on_issue: [:unsuported])
        end.to raise_error(ArgumentError, /unsuported/)
      end
    end
  end

  describe '#draw' do
    it 'emits six operands for both fill and stroke Bezier curves' do
      pdf = Prawn::Document.new
      pdf.svg('<svg width="100" height="100"><path d="M 10 10 C 20 20 30 30 40 10 Z" fill="red" stroke="black"/></svg>')

      curves = pdf.state.page.content.stream.filtered_stream.lines.grep(/ c$/)
      expect(curves.map { |line| line.split.length - 1 }).to eq [6, 6]
    end

    describe 'font families' do
      let(:pdf) { Prawn::Document.new }
      let(:ttf) { File.expand_path('../../sample_ttf/OpenSans-SemiboldItalic.ttf', __dir__) }

      it 'leaves the font families of the Prawn document unchanged' do
        families = Marshal.load(Marshal.dump(pdf.font_families))
        svg = <<~SVG
          <svg width="100" height="100">
            <style>@font-face { font-family: Helvetica; src: url("OpenSans-SemiboldItalic.ttf"); }</style>
            <text y="50" font-family="Helvetica">hello</text>
          </svg>
        SVG

        pdf.svg(svg, file_requests: File.dirname(ttf))

        expect(pdf.font_families).to eq families
        expect(pdf.font.name).to eq 'Helvetica'
      end

      it 'does not load the installed fonts if there is no text' do
        expect_any_instance_of(Prawn::SVG::FontRegistry).not_to receive(:installed_fonts)
        expect(pdf.font_families).not_to receive(:replace)

        pdf.svg('<svg width="100" height="100"><rect width="10" height="10"/></svg>')
      end

      it 'renders text in installed fonts' do
        allow(Prawn::SVG::FontRegistry).to receive(:external_font_families).and_return('Installed' => { normal: ttf })
        rendered_fonts = []
        allow(pdf).to receive(:draw_text).and_wrap_original do |original, text, **options|
          rendered_fonts << pdf.font.family
          original.call(text, **options)
        end

        pdf.svg('<svg width="100" height="100"><text y="50" font-family="Installed">hello</text></svg>')

        expect(rendered_fonts).to eq ['Installed']
      end
    end

    context 'when the sizing object indicates the sizes are invalid' do
      let(:interface) { Prawn::SVG::Interface.new('<svg width="-1"></svg>', prawn, {}) }

      it "doesn't draw anything and adds a warning" do
        interface.draw
        expect(interface.document.warnings).to eq ['Negative sizing data means this SVG cannot be rendered']
      end
    end

    context 'when the SVG has a zero size' do
      let(:interface) { Prawn::SVG::Interface.new('<svg width="0"></svg>', prawn, {}) }

      it "doesn't draw anything or add an issue" do
        interface.draw
        expect(interface.document.issues).to be_empty
      end
    end

    context 'when an @import fails to load' do
      it 'includes the issue in the result' do
        result = Prawn::Document.new.svg('<svg width="10" height="10"><style>@import url("missing.css");</style></svg>')
        expect(result[:issues].map(&:category)).to eq [:resource]
        expect(result[:warnings]).to include(/Failed to load @import CSS from missing.css/)
      end
    end

    context 'when log_warnings is true' do
      let(:interface) { Prawn::SVG::Interface.new('<svg width="-1"></svg>', prawn, log_warnings: true) }

      it 'outputs warnings to stderr via warn' do
        expect { interface.draw }.to output("Negative sizing data means this SVG cannot be rendered\n").to_stderr
      end
    end

    context 'when log_issues is true' do
      let(:interface) { Prawn::SVG::Interface.new('<svg width="-1"></svg>', prawn, log_issues: true) }

      it 'outputs issues to stderr via warn' do
        expect { interface.draw }.to output("Negative sizing data means this SVG cannot be rendered\n").to_stderr
      end
    end

    describe 'raise_on_issue' do
      let(:interface) { Prawn::SVG::Interface.new('<svg width="-1"></svg>', prawn, raise_on_issue: raise_on_issue) }

      context 'when true' do
        let(:raise_on_issue) { true }

        it 'raises an IssueError containing the issues' do
          expect { interface.draw }.to raise_error(Prawn::SVG::IssueError, 'Negative sizing data means this SVG cannot be rendered') { |e|
            expect(e.issues).to eq [Prawn::SVG::Issue.new(:invalid, 'Negative sizing data means this SVG cannot be rendered')]
          }
        end
      end

      context 'when given a list including the issue category' do
        let(:raise_on_issue) { [:unsupported, :invalid] }

        it 'raises' do
          expect { interface.draw }.to raise_error(Prawn::SVG::IssueError)
        end
      end

      context 'when given a single category' do
        let(:raise_on_issue) { :invalid }

        it 'raises' do
          expect { interface.draw }.to raise_error(Prawn::SVG::IssueError)
        end
      end

      context 'when an issue was recorded while parsing the document' do
        let(:interface) do
          Prawn::SVG::Interface.new('<svg width="10" height="10"><style>@import url("missing.css");</style></svg>', Prawn::Document.new,
            raise_on_issue: [:resource])
        end

        it 'raises' do
          expect { interface.draw }.to raise_error(Prawn::SVG::IssueError, /Failed to load @import CSS/)
        end
      end

      context 'when given a list not including the issue category' do
        let(:raise_on_issue) { [:resource] }

        it 'does not raise' do
          expect { interface.draw }.not_to raise_error
        end
      end
    end

    context 'when an SVG image is drawn more than once' do
      let(:image_uri) { "data:image/svg+xml;base64,#{['<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><foo/></svg>'].pack('m0')}" }
      let(:svg) do
        <<~SVG
          <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
            <mask id="m" maskUnits="userSpaceOnUse"><image width="10" height="10" href="#{image_uri}"/></mask>
            <rect width="10" height="10" mask="url(#m)"/>
            <rect width="10" height="10" mask="url(#m)"/>
          </svg>
        SVG
      end

      it 'records the image issues once' do
        result = Prawn::Document.new.svg(svg)
        expect(result[:issues]).to eq [Prawn::SVG::Issue.new(:unknown, "Unknown tag 'foo'; ignoring")]
      end
    end

    describe 'huge and tiny numbers' do
      nest = ->(n, inner) { ('<g transform="scale(1e38)">' * n) + inner + ('</g>' * n) }
      stops = '<stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>'
      {
        'a link in deeply nested transforms'     => nest[12, '<a href="h"><rect width="10" height="10"/></a>'],
        'a gradient in deeply nested transforms' => %(<linearGradient id="g" spreadMethod="reflect">#{stops}</linearGradient>#{nest[12,
          '<rect width="10" height="10" fill="url(#g)"/>']}),
        'an arc with huge radii'                 => '<path d="M0 0 A1e38 1e38 0 0 1 1e-38 1" stroke="black"/>',
        'a huge textLength percentage'           => '<text textLength="3e38%" dx="3e38%">hi</text>',
        'a marker with a tiny viewBox'           => '<marker id="m" viewBox="0 0 1 1e-320"><rect width="1" height="1"/></marker><path d="M0 0L9 9" marker-end="url(#m)"/>',
        'compounding relative font sizes'        => "#{'<g font-size="3e38em">' * 12}<text>x</text><rect width=\"1em\" height=\"1em\"/>#{'</g>' * 12}",
        'compounding nested viewport sizes'      => "#{'<svg width="3e38%" height="3e38%">' * 5}<circle r=\"1%\"/>#{'</svg>' * 5}",
        'a rotation by a huge angle'             => '<rect width="10" height="10" transform="rotate(3e38)"/>'
      }.each do |description, body|
        it "writes only finite numbers for #{description}" do
          pdf = Prawn::Document.new(compress: false)
          pdf.svg(%(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">#{body}</svg>))
          expect(pdf.render).not_to match(/\b(?:NaN|Inf|null)\b/)
        end
      end

      it 'treats numbers outside the single-precision range as invalid' do
        result = Prawn::Document.new.svg('<svg xmlns="http://www.w3.org/2000/svg"><rect x="1e999" width="10" height="10"/></svg>')
        expect(result[:warnings]).to eq ["Invalid value '1e999' for attribute 'x' on <rect>"]
      end
    end

    describe 'max_work' do
      let(:image_uri) { "data:image/svg+xml;base64,#{[%(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">#{'<rect width="1" height="1"/>' * 100}</svg>)].pack('m0')}" }
      let(:svg) { %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="5" height="5"/><image width="10" height="10" href="#{image_uri}"/></svg>) }

      it 'renders when the SVG needs no more work than allowed' do
        expect { Prawn::Document.new.svg(svg, max_work: 1000) }.not_to raise_error
      end

      it 'raises before anything is drawn when the SVG and its nested images need more work than allowed' do
        pdf = Prawn::Document.new
        content = pdf.state.page.content.stream.filtered_stream

        expect { pdf.svg(svg, max_work: 300) }.to raise_error Prawn::SVG::Document::WorkLimitExceeded
        expect(pdf.state.page.content.stream.filtered_stream).to eq content
      end

      it 'gives each draw the whole budget' do
        interface = Prawn::SVG::Interface.new(%(<svg xmlns="http://www.w3.org/2000/svg">#{'<rect width="1" height="1"/>' * 100}</svg>), Prawn::Document.new, max_work: 1000)
        interface.draw

        expect { interface.draw }.not_to raise_error
      end

      it 'charges nothing once drawing has started' do
        pdf = Prawn::Document.new
        interface = Prawn::SVG::Interface.new('<svg xmlns="http://www.w3.org/2000/svg"><text y="10">hi</text></svg>', pdf, {})
        drawing = false
        allow(pdf).to(receive(:save_font).and_wrap_original { |method, *args, &block| (drawing = true) && method.call(*args, &block) })
        allow(interface.document.work_budget).to(receive(:record).and_wrap_original { |method, units| drawing ? raise('charged while drawing') : method.call(units) })

        expect { interface.draw }.not_to raise_error
      end

      it 'charges text for every copy drawn' do
        rects = '<rect width="10" height="10" clip-path="url(#c)"/>' * 20
        svg = %(<svg xmlns="http://www.w3.org/2000/svg"><clipPath id="c"><text y="10">#{'x' * 1000}</text></clipPath>#{rects}</svg>)

        expect { Prawn::Document.new.svg(svg, max_work: 50_000) }.not_to raise_error
        expect { Prawn::Document.new.svg(svg, max_work: 10_000) }.to raise_error Prawn::SVG::Document::WorkLimitExceeded
      end

      it 'charges for matching CSS selectors against elements' do
        rects = '<rect width="1" height="1"/>' * 1000
        style = %(<style>#{(1..500).map { |n| "g.c#{n} rect" }.join(',')} { fill: red; }</style>)

        expect { Prawn::Document.new.svg(%(<svg xmlns="http://www.w3.org/2000/svg">#{rects}</svg>), max_work: 20_000) }.not_to raise_error
        expect do
          Prawn::Document.new.svg(%(<svg xmlns="http://www.w3.org/2000/svg">#{style}#{rects}</svg>), max_work: 20_000)
        end.to raise_error Prawn::SVG::Document::WorkLimitExceeded
      end
    end

    context 'when log_warnings is not set' do
      let(:interface) { Prawn::SVG::Interface.new('<svg width="-1"></svg>', prawn, {}) }

      it 'does not output warnings to stderr' do
        expect { interface.draw }.not_to output.to_stderr
      end
    end

    describe 'rewrites' do
      before do
        [:save_font, :bounding_box].each { |message| allow(prawn).to receive(message).and_yield }
        allow(prawn).to receive_messages([:move_to, :line_to, :close_path, :fill_color, :stroke_color,
                                          :transformation_matrix, :restore_graphics_state])
        allow(prawn).to receive(:save_graphics_state) { |&block| block&.call }
      end

      context 'when fill_and_stroke is issued' do
        def expect_rectangle
          if RUBY_VERSION.start_with?('2.7.')
            expect(prawn).to receive(:rectangle)
          else
            expect(prawn).to receive(:rectangle).with([0, 100], 10, 10)
          end
        end

        context 'and fill rule is not set' do
          let(:interface) do
            Prawn::SVG::Interface.new('<svg width="250" height="100"><rect width="10" height="10" stroke="red"></rect></svg>',
              prawn, {})
          end

          it "adds content 'f' then 'S'" do
            expect_rectangle
            expect(prawn).to receive(:rectangle).with([0, 100], 10, 10) # path replayed for stroke
            expect(prawn).to receive(:add_content).with('W n')
            expect(prawn).to receive(:add_content).with('f')
            expect(prawn).to receive(:add_content).with('S')
            interface.draw
          end
        end

        context 'and fill rule is evenodd' do
          let(:interface) do
            Prawn::SVG::Interface.new(
              '<svg width="250" height="100"><rect width="10" height="10" stroke="red" fill-rule="evenodd"></rect></svg>', prawn, {}
            )
          end

          it "adds content 'f*' then 'S'" do
            expect_rectangle
            expect(prawn).to receive(:rectangle).with([0, 100], 10, 10) # path replayed for stroke
            expect(prawn).to receive(:add_content).with('W n')
            expect(prawn).to receive(:add_content).with('f*')
            expect(prawn).to receive(:add_content).with('S')
            interface.draw
          end
        end
      end
    end
  end

  describe '#position' do
    subject { interface.position }

    context 'when options[:at] supplied' do
      let(:interface) { Prawn::SVG::Interface.new(svg, prawn, at: [1, 2], position: :left) }

      it 'returns options[:at]' do
        expect(subject).to eq [1, 2]
      end
    end

    context 'when only a position is supplied' do
      let(:interface) { Prawn::SVG::Interface.new(svg, prawn, position: position) }

      context '(:left)' do
        let(:position) { :left }
        it { is_expected.to eq [0, 600] }
      end

      context '(:center)' do
        let(:position) { :center }
        it { is_expected.to eq [275, 600] }
      end

      context '(:right)' do
        let(:position) { :right }
        it { is_expected.to eq [550, 600] }
      end

      context 'a number' do
        let(:position) { 25.5 }
        it { is_expected.to eq [25.5, 600] }
      end
    end

    context 'when a vposition is supplied' do
      let(:interface) { Prawn::SVG::Interface.new(svg, prawn, vposition: vposition) }

      context '(:top)' do
        let(:vposition) { :top }
        it { is_expected.to eq [0, 600] }
      end

      context '(:center)' do
        let(:vposition) { :center }
        it { is_expected.to eq [0, 350] }
      end

      context '(:bottom)' do
        let(:vposition) { :bottom }
        it { is_expected.to eq [0, 100] }
      end

      context 'a number' do
        let(:vposition) { 25.5 }
        it { is_expected.to eq [0, 600 - 25.5] }
      end
    end
  end

  describe '#sizing and #resize' do
    let(:interface) { Prawn::SVG::Interface.new(svg, prawn, {}) }

    it 'allows the advanced user to resize the SVG after learning about its dimensions' do
      expect(interface.sizing.output_width).to eq 250
      expect(interface.sizing.output_height).to eq 100

      interface.resize(width: 500)

      expect(interface.sizing.output_width).to eq 500
      expect(interface.sizing.output_height).to eq 200
    end
  end
end
