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
end
