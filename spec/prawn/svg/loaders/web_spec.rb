require 'spec_helper'

RSpec.describe Prawn::SVG::Loaders::Web do
  let(:url) { 'http://hello.there/path' }
  let(:web_requests) { ->(uri) { "fetched #{uri}" } }

  subject { Prawn::SVG::Loaders::Web.new(web_requests).from_url(url) }

  context 'when web_requests is true' do
    let(:web_requests) { true }

    it 'loads the URL through ssrf_filter' do
      expect(SsrfFilter).to receive(:get).with(URI(url), {}) { |*, &block| http_response(Net::HTTPOK, body: 'hello!').tap(&block) }
      expect(subject).to eq 'hello!'
    end
  end

  ['http://hello.there/path', 'https://hello.there/path', 'HTTP://hello.there/path'].each do |web_url|
    context "with #{web_url}" do
      let(:url) { web_url }

      it 'calls the callable with the URI' do
        expect(subject).to eq "fetched #{URI(web_url)}"
      end
    end
  end

  ['file:///etc/passwd', 'ftp://hello.there/', 'javascript:alert(1)', 'gopher://hello.there/', 'data:image/png;base64,AA==',
   '//hello.there/path', 'relative/path.png', 'http://a b/', 'http://[bad/'].each do |other_url|
    context "with #{other_url}" do
      let(:url) { other_url }
      let(:web_requests) { ->(_uri) { raise 'should not be called' } }

      it 'returns nil without making a request' do
        expect(subject).to be_nil
      end
    end
  end

  ['http:foo', 'https:', 'http:///foo'].each do |hostless_url|
    context "with #{hostless_url}" do
      let(:url) { hostless_url }
      let(:web_requests) { ->(_uri) { raise 'should not be called' } }

      it 'raises a Requests::Error' do
        expect { subject }.to raise_error Prawn::SVG::Requests::Error, 'web URL has no host'
      end
    end
  end

  [false, nil].each do |disabled|
    context "when web_requests is #{disabled.inspect}" do
      let(:web_requests) { disabled }

      it 'raises a Requests::Error for web URLs' do
        expect { subject }.to raise_error Prawn::SVG::Requests::Error, 'web requests are disabled; see the :web_requests option'
      end

      context 'with a non-web URL' do
        let(:url) { 'relative/path.png' }

        it 'returns nil' do
          expect(subject).to be_nil
        end
      end
    end
  end

  context 'when the callable raises a Requests::Error' do
    let(:web_requests) { ->(_uri) { raise Prawn::SVG::Requests::Error, 'argh' } }

    it 'passes it on' do
      expect { subject }.to raise_error Prawn::SVG::Requests::Error, 'argh'
    end
  end

  context 'when the callable raises any other error' do
    let(:web_requests) { ->(_uri) { raise SocketError, 'argh' } }

    it 'does not convert it' do
      expect { subject }.to raise_error SocketError, 'argh'
    end
  end

  context 'when the callable returns something other than a String' do
    let(:web_requests) { ->(_uri) { http_response(Net::HTTPOK, body: 'hello!') } }

    it 'raises a TypeError' do
      expect { subject }.to raise_error TypeError, /returned .* instead of a String/
    end
  end

  context 'when the callable returns nil' do
    let(:web_requests) { ->(_uri) {} }

    it 'raises a TypeError' do
      expect { subject }.to raise_error TypeError, 'web request returned NilClass instead of a String'
    end
  end

  ['yes', 1, 'true'].each do |invalid|
    context "when web_requests is #{invalid.inspect}" do
      let(:web_requests) { invalid }

      it 'raises an ArgumentError' do
        expect { subject }.to raise_error ArgumentError, ':web_requests must be true, false or a callable'
      end
    end
  end
end
