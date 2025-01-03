require 'spec_helper'

describe Prawn::SVG::Attributes::Opacity do
  class OpacityTestElement
    include Prawn::SVG::Attributes::Opacity

    attr_accessor :properties, :state

    def initialize
      @properties = ::Prawn::SVG::Properties.new
      @state = ::Prawn::SVG::State.new
    end

    def computed_properties
      @state.computed_properties
    end
  end

  let(:element) { OpacityTestElement.new }

  describe '#parse_opacity_attributes_and_call' do
    subject { element.parse_opacity_attributes_and_call }

    context 'with no opacity specified' do
      it 'does nothing' do
        expect(element).not_to receive(:add_call_and_enter)
        subject
      end
    end

    context 'with opacity' do
      it 'sets fill and stroke opacity' do
        element.computed_properties.opacity = '0.4'

        expect(element).to receive(:add_call_and_enter).with('transparent', 0.4, 0.4)
        subject

        expect(element.state.opacity).to eq 0.4
        expect(element.state.last_fill_opacity).to eq 0.4
        expect(element.state.last_stroke_opacity).to eq 0.4
      end
    end

    context 'with just fill opacity' do
      it 'sets fill opacity and sets stroke opacity to 1' do
        element.computed_properties.fill_opacity = '0.4'

        expect(element).to receive(:add_call_and_enter).with('transparent', 0.4, 1)
        subject

        expect(element.state.opacity).to eq 1
        expect(element.state.last_fill_opacity).to eq 0.4
        expect(element.state.last_stroke_opacity).to eq 1
      end
    end

    context 'with an existing stroke opacity' do
      it 'multiplies the new opacity by the old' do
        element.state.opacity = 0.5

        element.computed_properties.fill_opacity = '0.4'
        element.computed_properties.stroke_opacity = '0.5'

        expect(element).to receive(:add_call_and_enter).with('transparent', 0.2, 0.25)
        subject

        expect(element.state.opacity).to eq 0.5
        expect(element.state.last_fill_opacity).to eq 0.2
        expect(element.state.last_stroke_opacity).to eq 0.25
      end
    end

    context 'with stroke, fill, and opacity all specified' do
      it 'choses the lower of them' do
        element.computed_properties.fill_opacity = '0.4'
        element.computed_properties.stroke_opacity = '0.6'
        element.computed_properties.opacity = '0.5'

        expect(element).to receive(:add_call_and_enter).with('transparent', 0.2, 0.3)
        subject

        expect(element.state.opacity).to eq 0.5
        expect(element.state.last_fill_opacity).to eq 0.2
        expect(element.state.last_stroke_opacity).to eq 0.3
      end
    end
  end
end
