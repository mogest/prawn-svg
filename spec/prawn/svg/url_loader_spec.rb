require 'spec_helper'

describe Prawn::SVG::UrlLoader do
  let(:cache) { {} }
  let(:enable_web) { true }
  let(:file_requests) { ->(_path) {} }
  let(:loader) do
    Prawn::SVG::UrlLoader.new(cache: cache, web_requests: enable_web, file_requests: file_requests)
  end

  describe '#initialize' do
    it 'raises if the cache is not hash-like' do
      expect { Prawn::SVG::UrlLoader.new(cache: 42) }.to raise_error ArgumentError, /cache_requests/
    end
  end

  describe '#load' do
    let(:url) { 'http://hello/there' }
    let(:data_loader) { instance_double(Prawn::SVG::Loaders::Data) }
    let(:web_loader) { instance_double(Prawn::SVG::Loaders::Web) }
    let(:file_loader) { instance_double(Prawn::SVG::Loaders::File) }

    before do
      allow(Prawn::SVG::Loaders::Data).to receive(:new).and_return(data_loader)
      allow(Prawn::SVG::Loaders::Web).to receive(:new).and_return(web_loader)
      allow(Prawn::SVG::Loaders::File).to receive(:new).with(file_requests).and_return(file_loader)
    end

    subject { loader.load(url) }

    it 'calls the Data loader and returns its output if successful' do
      expect(data_loader).to receive(:from_url).with(url).and_return('data')
      expect(web_loader).not_to receive(:from_url)

      expect(subject).to eq 'data'
    end

    it 'calls the Web loader if the Data loader returns nothing, and returns its output if successful' do
      expect(data_loader).to receive(:from_url).with(url)
      expect(web_loader).to receive(:from_url).with(url).and_return('data')

      expect(subject).to eq 'data'
    end

    it 'calls the File loader if the Data and Web loaders return nothing, and returns its output if successful' do
      expect(data_loader).to receive(:from_url).with(url)
      expect(web_loader).to receive(:from_url).with(url)
      expect(file_loader).to receive(:from_url).with(url).and_return('data')

      expect(subject).to eq 'data'
    end

    it 'raises if none of the loaders return any data' do
      expect(data_loader).to receive(:from_url).with(url)
      expect(web_loader).to receive(:from_url).with(url)
      expect(file_loader).to receive(:from_url).with(url)

      expect { subject }.to raise_error(Prawn::SVG::Requests::Error, /No handler available/)
    end

    it 'caches the result' do
      expect(data_loader).to receive(:from_url).with(url).and_return('data')
      expect(subject).to eq 'data'
      expect(cache[url]).to eq 'data'
    end

    context 'with a data URL' do
      let(:url) { 'data:text/plain,hello' }

      it 'does not cache the result' do
        expect(data_loader).to receive(:from_url).with(url).and_return('hello')
        expect(subject).to eq 'hello'
        expect(cache).to be_empty
      end
    end

    context 'when caching is disabled' do
      let(:cache) { false }

      it 'loads the URL every time' do
        expect(data_loader).to receive(:from_url).with(url).twice.and_return('data')
        2.times { expect(loader.load(url)).to eq 'data' }
      end
    end

    context 'when the cache is populated' do
      let(:cache) { { url => 'data' } }

      it 'returns the cached value without calling a loader' do
        expect(data_loader).not_to receive(:from_url)
        expect(web_loader).not_to receive(:from_url)

        expect(subject).to eq 'data'
      end
    end
  end
end
