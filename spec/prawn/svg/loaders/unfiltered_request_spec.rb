require 'spec_helper'

RSpec.describe Prawn::SVG::Loaders::UnfilteredRequest do
  it 'fetches from a local server' do
    with_http_server('/a' => raw_http_response('200 OK', 'hello!')) do |base_url, _|
      expect(described_class.new.call(URI("#{base_url}/a"))).to eq 'hello!'
    end
  end

  it 'follows redirects, including relative ones' do
    responses = {
      '/a' => raw_http_response('302 Found', '', 'Location' => '/b'),
      '/b' => raw_http_response('200 OK', 'hello!')
    }

    with_http_server(responses) do |base_url, requested|
      expect(described_class.new.call(URI("#{base_url}/a"))).to eq 'hello!'
      expect(requested).to eq ['/a', '/b']
    end
  end

  it 'gives up after too many redirects' do
    with_http_server('/a' => raw_http_response('302 Found', '', 'Location' => '/a')) do |base_url, requested|
      expect { described_class.new(max_redirects: 2).call(URI("#{base_url}/a")) }.to raise_error Prawn::SVG::UrlLoader::Error, 'too many redirects'
      expect(requested.length).to eq 3
    end
  end

  ['file:///etc/passwd', 'http:///x'].each do |location|
    it "refuses to follow a redirect to #{location}" do
      with_http_server('/a' => raw_http_response('302 Found', '', 'Location' => location)) do |base_url, _|
        expect { described_class.new.call(URI("#{base_url}/a")) }.to raise_error Prawn::SVG::UrlLoader::Error, /redirected to unsupported URL/
      end
    end
  end

  it 'raises a UrlLoader error when the response is not a 2xx' do
    with_http_server({}) do |base_url, _|
      expect { described_class.new.call(URI("#{base_url}/missing")) }.to raise_error Prawn::SVG::UrlLoader::Error, 'request failed with status 404 Not Found'
    end
  end

  it 'passes Net::HTTP options through' do
    with_http_server('/a' => raw_http_response('200 OK', 'hello!')) do |base_url, _|
      expect(Net::HTTP).to receive(:start).with('127.0.0.1', anything, use_ssl: false, read_timeout: 3).and_call_original
      expect(described_class.new(read_timeout: 3).call(URI("#{base_url}/a"))).to eq 'hello!'
    end
  end

  it 'refuses a response larger than max_response_bytes' do
    with_http_server('/a' => raw_http_response('200 OK', 'x' * 1001)) do |base_url, _|
      expect(described_class.new(max_response_bytes: 1001).call(URI("#{base_url}/a"))).to eq 'x' * 1001
      expect { described_class.new(max_response_bytes: 1000).call(URI("#{base_url}/a")) }.to raise_error Prawn::SVG::UrlLoader::Error, 'response is larger than 1000 bytes'
    end
  end

  it 'applies max_response_bytes to the decompressed response' do
    body = Zlib.gzip(' ' * 1_000_000)
    with_http_server('/a' => raw_http_response('200 OK', body, 'Content-Encoding' => 'gzip')) do |base_url, _|
      expect { described_class.new(max_response_bytes: 100_000).call(URI("#{base_url}/a")) }.to raise_error Prawn::SVG::UrlLoader::Error, /larger than/
    end
  end

  it 'gives up when the whole request takes longer than total_timeout' do
    server = TCPServer.new('127.0.0.1', 0)
    thread = Thread.new do
      client = server.accept
      client.write "HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\n"
      100.times { client.write('a') && sleep(0.05) }
    end

    expect { described_class.new(total_timeout: 0.2).call(URI("http://127.0.0.1:#{server.addr[1]}/")) }.to raise_error Prawn::SVG::UrlLoader::Error, 'request timed out'
  ensure
    thread&.kill
    server&.close
  end

  it 'raises a UrlLoader error when the connection is refused' do
    port = TCPServer.open('127.0.0.1', 0) { |server| server.addr[1] }
    expect { described_class.new.call(URI("http://127.0.0.1:#{port}/")) }.to raise_error Prawn::SVG::UrlLoader::Error, /refused/i
  end
end
