require 'spec_helper'

describe Prawn::SVG::Interface do
  let(:bounds) { double(width: 800, height: 600, absolute_left: 0, absolute_top: 0) }
  let(:prawn)  { instance_double(Prawn::Document, font_families: {}, bounds: bounds, cursor: 600) }
  let(:svg)    { '<svg width="250" height="100"></svg>' }

  describe '#initialize' do
    describe 'invalid option detection' do
      it 'rejects invalid options when debug is on' do
        allow(Prawn).to receive(:debug).and_return(true)

        expect do
          Prawn::SVG::Interface.new(svg, prawn, invalid: 'option')
        end.to raise_error(Prawn::Errors::UnknownOption)
      end

      it 'accepts a single raise_on_issue category' do
        expect do
          Prawn::SVG::Interface.new(svg, prawn, raise_on_issue: :unsupported, enable_web_requests: false)
        end.not_to raise_error
      end

      it 'rejects unknown raise_on_issue categories' do
        expect do
          Prawn::SVG::Interface.new(svg, prawn, raise_on_issue: [:unsuported], enable_web_requests: false)
        end.to raise_error(ArgumentError, /unsuported/)
      end

      it 'does nothing if an invalid option is given and debug is off' do
        Prawn::SVG::Interface.new(svg, prawn, invalid: 'option', enable_web_requests: false)
      end
    end
  end

  describe '#draw' do
    it 'emits six operands for both fill and stroke Bezier curves' do
      pdf = Prawn::Document.new
      pdf.svg('<svg width="100" height="100"><path d="M 10 10 C 20 20 30 30 40 10 Z" fill="red" stroke="black"/></svg>',
        enable_web_requests: false)

      curves = pdf.state.page.content.stream.filtered_stream.lines.grep(/ c$/)
      expect(curves.map { |line| line.split.length - 1 }).to eq [6, 6]
    end

    context 'when the sizing object indicates the sizes are invalid' do
      let(:interface) { Prawn::SVG::Interface.new('<svg width="-1"></svg>', prawn, { enable_web_requests: false }) }

      it "doesn't draw anything and adds a warning" do
        interface.draw
        expect(interface.document.warnings).to eq ['Negative sizing data means this SVG cannot be rendered']
      end
    end

    context 'when the SVG has a zero size' do
      let(:interface) { Prawn::SVG::Interface.new('<svg width="0"></svg>', prawn, { enable_web_requests: false }) }

      it "doesn't draw anything or add an issue" do
        interface.draw
        expect(interface.document.issues).to be_empty
      end
    end

    context 'when an @import fails to load' do
      it 'includes the issue in the result' do
        result = Prawn::Document.new.svg('<svg width="10" height="10"><style>@import url("missing.css");</style></svg>', enable_web_requests: false)
        expect(result[:issues].map(&:category)).to eq [:resource]
        expect(result[:warnings]).to include(/Failed to load @import CSS from missing.css/)
      end
    end

    context 'when log_warnings is true' do
      let(:interface) { Prawn::SVG::Interface.new('<svg width="-1"></svg>', prawn, log_warnings: true, enable_web_requests: false) }

      it 'outputs warnings to stderr via warn' do
        expect { interface.draw }.to output("Negative sizing data means this SVG cannot be rendered\n").to_stderr
      end
    end

    context 'when log_issues is true' do
      let(:interface) { Prawn::SVG::Interface.new('<svg width="-1"></svg>', prawn, log_issues: true, enable_web_requests: false) }

      it 'outputs issues to stderr via warn' do
        expect { interface.draw }.to output("Negative sizing data means this SVG cannot be rendered\n").to_stderr
      end
    end

    describe 'raise_on_issue' do
      let(:interface) { Prawn::SVG::Interface.new('<svg width="-1"></svg>', prawn, raise_on_issue: raise_on_issue, enable_web_requests: false) }

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
            raise_on_issue: [:resource], enable_web_requests: false)
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
        result = Prawn::Document.new.svg(svg, enable_web_requests: false)
        expect(result[:issues]).to eq [Prawn::SVG::Issue.new(:unsupported, "Unknown tag 'foo'; ignoring")]
      end
    end

    context 'when log_warnings is not set' do
      let(:interface) { Prawn::SVG::Interface.new('<svg width="-1"></svg>', prawn, { enable_web_requests: false }) }

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
              prawn, { enable_web_requests: false })
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
              '<svg width="250" height="100"><rect width="10" height="10" stroke="red" fill-rule="evenodd"></rect></svg>', prawn, { enable_web_requests: false }
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
      let(:interface) { Prawn::SVG::Interface.new(svg, prawn, at: [1, 2], position: :left, enable_web_requests: false) }

      it 'returns options[:at]' do
        expect(subject).to eq [1, 2]
      end
    end

    context 'when only a position is supplied' do
      let(:interface) { Prawn::SVG::Interface.new(svg, prawn, position: position, enable_web_requests: false) }

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
      let(:interface) { Prawn::SVG::Interface.new(svg, prawn, vposition: vposition, enable_web_requests: false) }

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
    let(:interface) { Prawn::SVG::Interface.new(svg, prawn, { enable_web_requests: false }) }

    it 'allows the advanced user to resize the SVG after learning about its dimensions' do
      expect(interface.sizing.output_width).to eq 250
      expect(interface.sizing.output_height).to eq 100

      interface.resize(width: 500)

      expect(interface.sizing.output_width).to eq 500
      expect(interface.sizing.output_height).to eq 200
    end
  end
end
