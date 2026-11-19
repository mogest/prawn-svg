require 'spec_helper'

RSpec.describe Prawn::SVG::CSS::ValuesParser do
  it 'parses specified values' do
    values = 'hello world url("#myid") no-quote(very good) escaping(")\\")ok") rgb( 1,4,  5 )'

    expect(described_class.parse(values)).to eq [
      'hello',
      'world',
      ['url', ['#myid']],
      ['no-quote', ['very good']],
      ['escaping', [')")ok']],
      ['rgb', %w[1 4 5]]
    ]
  end

  it 'parses values across newlines' do
    expect(described_class.parse("a\n url(#b)\n c")).to eq ['a', ['url', ['#b']], 'c']
  end

  it 'ends a function call that is not closed at the end of the values' do
    expect(described_class.parse('a rgb(1, 2 b')).to eq ['a', ['rgb', ['1', '2 b']]]
  end

  it 'parses many values in linear time' do
    values = 'url(#a) b ' * 20_000
    expect(described_class.parse(values).length).to eq 40_000
  end
end
