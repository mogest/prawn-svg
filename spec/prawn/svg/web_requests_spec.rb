require 'spec_helper'

RSpec.describe 'web requests' do
  let(:font_path) { File.expand_path('../../sample_ttf/OpenSans-SemiboldItalic.ttf', __dir__) }
  let(:png) { File.binread(File.expand_path('../../sample_images/mushroom-wide.jpg', __dir__)) }
  let(:nested_svg) { %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><image href="https://web.test/nested.jpg" width="10" height="10"/></svg>) }

  let(:hostile_svg) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">
        <style>
          @import url("https://web.test/a.css");
          @font-face { font-family: "Web"; src: url("https://web.test/font.ttf"); }
        </style>
        <image href="https://web.test/image.jpg" width="10" height="10"/>
        <image href="data:image/svg+xml;base64,#{[nested_svg].pack('m0')}" width="10" height="10"/>
        <use xlink:href="https://web.test/icons.svg#icon"/>
        <text font-family="Web" y="50">hello</text>
      </svg>
    SVG
  end

  let(:web) do
    {
      'https://web.test/a.css'      => '@import url("https://web.test/b.css"); rect { fill: red; }',
      'https://web.test/b.css'      => 'circle { fill: blue; }',
      'https://web.test/font.ttf'   => File.binread(font_path),
      'https://web.test/image.jpg'  => png,
      'https://web.test/nested.jpg' => png,
      'https://web.test/icons.svg'  => %(<svg xmlns="http://www.w3.org/2000/svg"><rect id="icon" width="5" height="5"/></svg>)
    }
  end

  def stub_ssrf_filter
    requested = []
    allow(SsrfFilter).to receive(:get) do |uri, _options|
      requested << uri.to_s
      web.key?(uri.to_s) ? http_response(Net::HTTPOK, body: web[uri.to_s]) : http_response(Net::HTTPNotFound, code: '404', message: 'Not Found')
    end
    requested
  end

  def render(svg, **options)
    pdf = Prawn::Document.new
    result = pdf.svg(svg, **options)
    pdf.render
    result
  end

  context 'with default options' do
    it 'makes no network connections from any part of the SVG' do
      expect(SsrfFilter).not_to receive(:get)
      expect(Net::HTTP).not_to receive(:start)
      expect(Socket).not_to receive(:tcp)
      expect(TCPSocket).not_to receive(:new)

      result = render(hostile_svg)

      expect(result[:issues].map(&:category).uniq).to eq [:resource]
      expect(result[:warnings].count { |w| w.include?('web requests are disabled') }).to eq 5
    end
  end

  context 'with web_requests: true' do
    it 'makes every request through ssrf_filter' do
      requested = stub_ssrf_filter
      expect(Net::HTTP).not_to receive(:start)

      result = render(hostile_svg, web_requests: true)

      expect(result[:warnings]).to be_empty
      expect(requested).to match_array web.keys
    end

    it 'behaves the same with the legacy enable_web_requests option' do
      requested = stub_ssrf_filter

      render(hostile_svg, enable_web_requests: true)

      expect(requested).to match_array web.keys
    end

    it 'reports a refused request as a resource issue, which raise_on_issue can make fatal' do
      allow(Resolv).to receive(:getaddresses).with('web.test').and_return(['169.254.169.254'])
      svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><image href="https://web.test/image.jpg" width="10" height="10"/></svg>)

      expect(render(svg, web_requests: true)[:warnings]).to eq [
        "Error retrieving URL https://web.test/image.jpg: refused potentially unsafe request: Hostname 'web.test' has no public ip addresses"
      ]
      expect { render(svg, web_requests: true, raise_on_issue: [:resource]) }.to raise_error Prawn::SVG::IssueError, /refused/
    end
  end

  it 'lets raise_on_issue make disabled requests fatal' do
    svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><image href="https://web.test/image.jpg" width="10" height="10"/></svg>)
    expect { render(svg, raise_on_issue: [:resource]) }.to raise_error Prawn::SVG::IssueError, /web requests are disabled/
  end

  describe 'a callable' do
    let(:svg) { %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><image href="https://web.test/image.jpg" width="10" height="10"/></svg>) }

    it 'aborts rendering with an unexpected error' do
      expect { render(svg, web_requests: ->(_uri) { raise ArgumentError, 'bug' }) }.to raise_error ArgumentError, 'bug'
    end

    it 'aborts rendering when it returns something other than a String' do
      expect { render(svg, web_requests: ->(_uri) { 1 }) }.to raise_error TypeError
    end

    it 'reports a UrlLoader error as a resource issue' do
      result = render(svg, web_requests: ->(_uri) { raise Prawn::SVG::UrlLoader::Error, 'nope' })
      expect(result[:warnings]).to eq ['Error retrieving URL https://web.test/image.jpg: nope']
    end
  end

  describe 'caching' do
    let(:image) { %(<image href="https://web.test/image.jpg" width="5" height="5"/>) }
    let(:svg) { %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">#{image}#{image}</svg>) }

    it 'requests a URL once with cache_images' do
      requested = stub_ssrf_filter
      render(svg, web_requests: true, cache_images: true)
      expect(requested).to eq ['https://web.test/image.jpg']
    end

    it 'does not cache failures' do
      web.delete('https://web.test/image.jpg')
      requested = stub_ssrf_filter
      render(svg, web_requests: true, cache_images: true)
      expect(requested).to eq ['https://web.test/image.jpg'] * 2
    end
  end
end
