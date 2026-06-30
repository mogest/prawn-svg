require 'spec_helper'

RSpec.describe Prawn::SVG::Loaders::SsrfFilterRequest do
  let(:uri) { URI('https://hello.there/path') }
  let(:options) { {} }

  subject { described_class.new(**options).call(uri) }

  it 'returns the body of a successful response' do
    expect(SsrfFilter).to receive(:get).with(uri, {}).and_return(http_response(Net::HTTPOK, body: 'hello!'))
    expect(subject).to eq 'hello!'
  end

  it 'returns an empty string for a successful response without a body' do
    expect(SsrfFilter).to receive(:get).and_return(http_response(Net::HTTPNoContent))
    expect(subject).to eq ''
  end

  context 'with ssrf_filter options' do
    let(:options) { { http_options: { open_timeout: 5 } } }

    it 'passes them through to ssrf_filter' do
      expect(SsrfFilter).to receive(:get).with(uri, options).and_return(http_response(Net::HTTPOK, body: 'hello!'))
      expect(subject).to eq 'hello!'
    end
  end

  it 'raises a UrlLoader error when the response is not a 2xx' do
    expect(SsrfFilter).to receive(:get).and_return(http_response(Net::HTTPNotFound, code: '404', message: 'Not Found'))
    expect { subject }.to raise_error Prawn::SVG::UrlLoader::Error, 'request failed with status 404 Not Found'
  end

  it 'raises a UrlLoader error explaining a refused private address' do
    expect(SsrfFilter).to receive(:get).and_raise(SsrfFilter::PrivateIPAddress, 'no public ip')
    expect { subject }.to raise_error Prawn::SVG::UrlLoader::Error, 'refused potentially unsafe request: no public ip'
  end

  [Net::OpenTimeout, Net::ReadTimeout].each do |error_class|
    it "raises a UrlLoader error when the request raises #{error_class}" do
      expect(SsrfFilter).to receive(:get).and_raise(error_class)
      expect { subject }.to raise_error Prawn::SVG::UrlLoader::Error, 'request timed out'
    end
  end

  [
    SsrfFilter::UnresolvedHostname, SsrfFilter::TooManyRedirects, Errno::ECONNREFUSED, SocketError,
    OpenSSL::SSL::SSLError, EOFError, URI::InvalidURIError, Net::HTTPBadResponse, Zlib::DataError
  ].each do |error_class|
    it "raises a UrlLoader error when the request raises #{error_class}" do
      expect(SsrfFilter).to receive(:get).and_raise(error_class, 'argh')
      expect { subject }.to raise_error Prawn::SVG::UrlLoader::Error, /argh/
    end
  end

  it 'does not convert unexpected errors' do
    expect(SsrfFilter).to receive(:get).and_raise(ArgumentError, 'argh')
    expect { subject }.to raise_error ArgumentError, 'argh'
  end

  context 'with the real ssrf_filter' do
    let(:uri) { URI('http://internal.test/') }

    ['127.0.0.1', '10.0.0.1', '169.254.169.254', '::1', '::ffff:127.0.0.1', '0.0.0.0'].each do |address|
      it "refuses a host resolving to #{address}" do
        allow(Resolv).to receive(:getaddresses).with('internal.test').and_return([address])
        expect(Net::HTTP).not_to receive(:start)

        expect { subject }.to raise_error Prawn::SVG::UrlLoader::Error, /refused potentially unsafe request/
      end
    end

    it 'refuses an IP address URL' do
      expect(Net::HTTP).not_to receive(:start)
      expect { described_class.new.call(URI('http://169.254.169.254/latest/meta-data/')) }.to raise_error Prawn::SVG::UrlLoader::Error, /refused/
    end

    it 'refuses a redirect to a private address' do
      allow(Resolv).to receive(:getaddresses).with('public.test').and_return(['93.184.215.14'])
      allow(Resolv).to receive(:getaddresses).with('internal.test').and_return(['10.0.0.1'])

      redirect = Net::HTTPFound.new('1.1', '302', 'Found')
      redirect['location'] = 'http://internal.test/secret'
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request).and_return(redirect)
      expect(Net::HTTP).to receive(:start).once.with('public.test', 80, nil, hash_including(ipaddr: '93.184.215.14')).and_yield(http)

      expect { described_class.new.call(URI('http://public.test/')) }.to raise_error Prawn::SVG::UrlLoader::Error, /refused potentially unsafe request/
    end

    it 'refuses to connect to a local server' do
      with_http_server('/' => raw_http_response('200 OK', 'secret')) do |base_url, requested|
        expect { described_class.new.call(URI(base_url)) }.to raise_error Prawn::SVG::UrlLoader::Error, /refused/
        expect(requested).to be_empty
      end
    end
  end
end
