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
    allow(SsrfFilter).to receive(:get) do |uri, _options, &block|
      requested << uri.to_s
      response = web.key?(uri.to_s) ? http_response(Net::HTTPOK, body: web[uri.to_s]) : http_response(Net::HTTPNotFound, code: '404', message: 'Not Found')
      block.call(response)
      response
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

    it 'reports a Requests::Error as a resource issue' do
      result = render(svg, web_requests: ->(_uri) { raise Prawn::SVG::Requests::Error, 'nope' })
      expect(result[:warnings]).to eq ['Error retrieving URL https://web.test/image.jpg: nope']
    end
  end

  describe 'content fetched from the web' do
    before { expect_any_instance_of(Prawn::SVG::Loaders::File).not_to receive(:from_url) }

    let!(:requested) { stub_ssrf_filter }
    let(:options) { { web_requests: true, file_requests: File.expand_path('../..', __dir__) } }

    it 'resolves an external SVG\'s references against its URL, and may not reference files' do
      web['https://web.test/icons.svg'] = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <g id="icon">
            <image href="nested.jpg" width="5" height="5"/>
            <image xlink:href="file:///etc/passwd" width="5" height="5"/>
          </g>
        </svg>
      SVG
      svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><use href="https://web.test/icons.svg#icon"/></svg>)

      result = render(svg, **options)

      expect(requested).to eq ['https://web.test/icons.svg', 'https://web.test/nested.jpg']
      expect(result[:warnings]).to eq ["external SVG from 'https://web.test/icons.svg' may not reference 'file:///etc/passwd'"]
    end

    it 'resolves a stylesheet\'s references against its URL, and may not reference files' do
      web['https://web.test/a.css'] = <<~CSS
        @import "b.css";
        @import url("file:///etc/passwd");
        @font-face { font-family: "Web"; src: url("font.ttf"); }
        @font-face { font-family: "Local"; src: url("spec/sample_ttf/OpenSans-SemiboldItalic.ttf"); }
        @font-face { font-family: "File"; src: url("file:///etc/passwd"); }
      CSS
      web['https://web.test/b.css'] = '@import "../../etc/passwd";'
      svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><style>@import url("https://web.test/a.css");</style></svg>)

      result = render(svg, **options)

      expect(requested).to match_array [
        'https://web.test/a.css', 'https://web.test/b.css', 'https://web.test/etc/passwd',
        'https://web.test/font.ttf', 'https://web.test/spec/sample_ttf/OpenSans-SemiboldItalic.ttf'
      ]
      expect(result[:warnings]).to include(
        "stylesheet from 'https://web.test/a.css' may not reference 'file:///etc/passwd'"
      )
      expect(result[:warnings].grep(/file:/).length).to eq 2
    end

    it 'checks @font-face sources after comments are removed' do
      web['https://web.test/a.css'] = <<~CSS
        @font-face { font-family: "A"; src: u/**/rl(spec/sample_ttf/OpenSans-SemiboldItalic.ttf); }
        @font-face { font-family: "B"; src: url/**/(spec/sample_ttf/NotoSansJP-Regular.ttf); }
        <!-- @font-face { font-family: "C"; src: url(spec/sample_ttf/TestFamily.ttc); } -->
      CSS
      svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><style>@import url("https://web.test/a.css");</style></svg>)

      render(svg, **options)

      expect(requested - ['https://web.test/a.css']).to all(start_with('https://web.test/spec/sample_ttf/'))
    end

    it 'restricts namespace-prefixed elements, rebases fragment references and refuses data: <use>' do
      inner = %(<svg xmlns="http://www.w3.org/2000/svg"><g id="y"><image href="spec/sample_images/mushroom-wide.jpg" width="5" height="5"/></g></svg>)
      web['https://web.test/spec/sample_images/mushroom-wide.jpg'] = png
      web['https://web.test/spec/sample_images/mushroom-long.jpg'] = png
      web['https://web.test/icons.svg'] = <<~SVG
        <s:svg xmlns:s="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:x="urn:x">
          <s:g id="icon">
            <s:image xlink:href="spec/sample_images/mushroom-wide.jpg" width="5" height="5"/>
            <s:image href="spec/sample_images/mushroom-long.jpg" x:href="other" width="5" height="5"/>
            <s:use href="#m"/>
            <s:use xlink:href="data:image/svg+xml;base64,#{[inner].pack('m0')}#y"/>
          </s:g>
        </s:svg>
      SVG
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <defs><rect id="m" width="5" height="5"/></defs>
          <use href="https://web.test/icons.svg#icon"/>
        </svg>
      SVG

      result = render(svg, **options)

      expect(requested).to eq [
        'https://web.test/icons.svg', 'https://web.test/spec/sample_images/mushroom-wide.jpg', 'https://web.test/spec/sample_images/mushroom-long.jpg'
      ]
      expect(result[:warnings]).to contain_exactly(
        start_with("external SVG from 'https://web.test/icons.svg' may not reference 'data:"),
        "use tag references 'https://web.test/icons.svg#m' which could not be resolved"
      )
    end
  end

  describe 'corrupt content fetched from the web' do
    let(:svg) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <style>@import url("https://web.test/a.css"); @font-face { font-family: "Web"; src: url("https://web.test/font.ttf"); }</style>
          <text font-family="Web" y="5">hello</text>
        </svg>
      SVG
    end

    it 'is reported as issues rather than crashing' do
      web['https://web.test/a.css'] = '5 { fill: red; }'
      web['https://web.test/font.ttf'] = File.binread(font_path)[0, 1000]
      stub_ssrf_filter

      result = render(svg, web_requests: true)

      expect(result[:warnings]).to contain_exactly(
        "CSS selector '5' could not be parsed",
        'Failed to load @font-face font from https://web.test/font.ttf: font data could not be parsed'
      )
    end

    it 'reports oversized entities in external and nested SVGs as issues' do
      entities = %(<!DOCTYPE svg [<!ENTITY a "#{'x' * 1000}"><!ENTITY b "#{'&a;' * 16}">]>)
      web['https://web.test/e.svg'] = %(#{entities}<svg xmlns="http://www.w3.org/2000/svg"><g id="x"><text>&b;</text></g></svg>)
      stub_ssrf_filter
      references = %(<use href="https://web.test/e.svg#x"/><image href="https://web.test/e.svg" width="5" height="5"/>)
      svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">#{references}</svg>)

      expect(render(svg, web_requests: true)[:warnings]).to contain_exactly(
        "use tag references external SVG at 'https://web.test/e.svg' which could not be parsed",
        'image tag references SVG data which could not be parsed'
      )
    end

    it 'reports issues in the stylesheets of external SVGs' do
      web['https://web.test/e.svg'] = %(<svg xmlns="http://www.w3.org/2000/svg"><style>5 { fill: red; }</style><rect id="x" width="1" height="1"/></svg>)
      stub_ssrf_filter
      svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><use href="https://web.test/e.svg#x"/></svg>)

      expect(render(svg, web_requests: true)[:warnings]).to eq ["CSS selector '5' could not be parsed"]
    end
  end

  describe 'caching' do
    let(:image) { %(<image href="https://web.test/image.jpg" width="5" height="5"/>) }
    let(:svg) { %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">#{image}#{image}</svg>) }

    it 'requests a URL once per render, even without cache_requests' do
      requested = stub_ssrf_filter
      render(svg, web_requests: true)
      render(svg, web_requests: true)
      expect(requested).to eq ['https://web.test/image.jpg'] * 2
    end

    it 'requests a failing URL once per render' do
      web.delete('https://web.test/image.jpg')
      requested = stub_ssrf_filter
      result = render(svg, web_requests: true)
      expect(requested).to eq ['https://web.test/image.jpg']
      expect(result[:warnings].length).to eq 1
    end

    it 'requests an @import stylesheet once per render, including from nested documents' do
      nested = %(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><style>@import url("https://web.test/b.css");</style></svg>)
      image = %(<image href="data:image/svg+xml;base64,#{[nested].pack('m0')}" width="5" height="5"/>)
      requested = stub_ssrf_filter
      render(%(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">#{image * 3}</svg>), web_requests: true)
      expect(requested).to eq ['https://web.test/b.css']
    end

    it 'gives nested documents responses added to the root URL loader cache' do
      nested = %(<image href="data:image/svg+xml;base64,#{[svg].pack('m0')}" width="5" height="5"/>)
      expect(SsrfFilter).not_to receive(:get)
      pdf = Prawn::Document.new
      result = pdf.svg(%(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">#{nested}</svg>), web_requests: true) do |doc|
        doc.url_loader.add_to_cache('https://web.test/image.jpg', png)
      end
      expect(result[:warnings]).to be_empty
    end

    it 'shares responses with nested documents' do
      nested = %(<image href="data:image/svg+xml;base64,#{[svg].pack('m0')}" width="5" height="5"/>)
      requested = stub_ssrf_filter
      render(%(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">#{image}#{nested}</svg>), web_requests: true)
      expect(requested).to eq ['https://web.test/image.jpg']
    end
  end
end
