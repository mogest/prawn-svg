require 'spec_helper'

RSpec.describe Prawn::SVG::Attributes::Stroke do
  let(:document) { Prawn::SVG::Document.new(svg, [800, 600], { width: 800, height: 600 }) }

  subject do
    Prawn::SVG::Elements::Line.new(document, document.root, [], fake_state)
  end

  describe 'stroke-dashoffset' do
    context 'with a positive dashoffset' do
      let(:svg) { '<line x1="0" y1="0" x2="100" y2="0" stroke="black" stroke-dasharray="10,5" stroke-dashoffset="3"/>' }

      it 'passes phase option to dash call' do
        subject.process
        dash_call = subject.base_calls.detect { |c| c[0] == 'dash' }
        expect(dash_call).to eq ['dash', [[10.0, 5.0]], { phase: 3.0 }, []]
      end
    end

    context 'with a negative dashoffset' do
      let(:svg) { '<line x1="0" y1="0" x2="100" y2="0" stroke="black" stroke-dasharray="10,5" stroke-dashoffset="-7"/>' }

      it 'passes negative phase option to dash call' do
        subject.process
        dash_call = subject.base_calls.detect { |c| c[0] == 'dash' }
        expect(dash_call).to eq ['dash', [[10.0, 5.0]], { phase: -7.0 }, []]
      end
    end

    context 'with zero dashoffset' do
      let(:svg) { '<line x1="0" y1="0" x2="100" y2="0" stroke="black" stroke-dasharray="10,5" stroke-dashoffset="0"/>' }

      it 'does not pass phase option' do
        subject.process
        dash_call = subject.base_calls.detect { |c| c[0] == 'dash' }
        expect(dash_call).to eq ['dash', [[10.0, 5.0]], {}, []]
      end
    end

    context 'with no dashoffset specified' do
      let(:svg) { '<line x1="0" y1="0" x2="100" y2="0" stroke="black" stroke-dasharray="10,5"/>' }

      it 'does not pass phase option' do
        subject.process
        dash_call = subject.base_calls.detect { |c| c[0] == 'dash' }
        expect(dash_call).to eq ['dash', [[10.0, 5.0]], {}, []]
      end
    end

    context 'with dashoffset set via style attribute' do
      let(:svg) { '<line x1="0" y1="0" x2="100" y2="0" stroke="black" style="stroke-dasharray: 10,5; stroke-dashoffset: 8"/>' }

      it 'passes phase option to dash call' do
        subject.process
        dash_call = subject.base_calls.detect { |c| c[0] == 'dash' }
        expect(dash_call).to eq ['dash', [[10.0, 5.0]], { phase: 8.0 }, []]
      end
    end

    context 'with inherited dashoffset' do
      let(:svg) { '<g stroke-dashoffset="5"><line x1="0" y1="0" x2="100" y2="0" stroke="black" stroke-dasharray="10,5"/></g>' }
      let(:element) { Prawn::SVG::Elements::Container.new(document, document.root, [], fake_state) }

      it 'inherits the dashoffset from the parent' do
        element.process
        dash_call = flatten_calls(element.base_calls).detect { |c| c[0] == 'dash' }
        expect(dash_call).to eq ['dash', [[10.0, 5.0]], { phase: 5.0 }]
      end
    end

    context 'with inherited dashoffset overridden to zero on child' do
      let(:svg) { '<g stroke-dashoffset="5"><line x1="0" y1="0" x2="100" y2="0" stroke="black" stroke-dasharray="10,5" stroke-dashoffset="0"/></g>' }
      let(:element) { Prawn::SVG::Elements::Container.new(document, document.root, [], fake_state) }

      it 'uses the child zero offset, not the parent offset' do
        element.process
        dash_call = flatten_calls(element.base_calls).detect { |c| c[0] == 'dash' }
        expect(dash_call).to eq ['dash', [[10.0, 5.0]], {}]
      end
    end
  end

  describe 'stroke-miterlimit' do
    context 'with a miterlimit attribute' do
      let(:svg) { '<line x1="0" y1="0" x2="100" y2="0" stroke="black" stroke-miterlimit="8"/>' }

      it 'generates a miter_limit call' do
        subject.process
        call = subject.base_calls.detect { |c| c[0] == 'miter_limit' }
        expect(call).to eq ['miter_limit', [8.0], {}, []]
      end
    end

    context 'with miterlimit set via style attribute' do
      let(:svg) { '<line x1="0" y1="0" x2="100" y2="0" stroke="black" style="stroke-miterlimit: 10"/>' }

      it 'generates a miter_limit call' do
        subject.process
        call = subject.base_calls.detect { |c| c[0] == 'miter_limit' }
        expect(call).to eq ['miter_limit', [10.0], {}, []]
      end
    end

    context 'with miterlimit less than 1' do
      let(:svg) { '<line x1="0" y1="0" x2="100" y2="0" stroke="black" stroke-miterlimit="0.5"/>' }

      it 'rejects the invalid value' do
        subject.process
        call = subject.base_calls.detect { |c| c[0] == 'miter_limit' }
        expect(call).to be_nil
      end
    end

    context 'with inherited miterlimit' do
      let(:svg) { '<g stroke-miterlimit="12"><line x1="0" y1="0" x2="100" y2="0" stroke="black"/></g>' }
      let(:element) { Prawn::SVG::Elements::Container.new(document, document.root, [], fake_state) }

      it 'inherits the miterlimit from the parent' do
        element.process
        call = flatten_calls(element.base_calls).detect { |c| c[0] == 'miter_limit' }
        expect(call).to eq ['miter_limit', [12.0], {}]
      end
    end
  end
end
