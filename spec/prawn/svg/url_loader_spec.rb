require 'spec_helper'

describe Prawn::SVG::UrlLoader do
  let(:enable_cache) { true }
  let(:enable_web)   { true }
  let(:loader) { Prawn::SVG::UrlLoader.new(enable_cache: enable_cache, enable_web: enable_web) }

  describe "#initialize" do
    it "sets options" do
      expect(loader.enable_cache).to be true
      expect(loader.enable_web).to be true
    end
  end

  describe "#load" do
    let(:url) { "http://hello/there" }

    subject { loader.load(url) }

    it "calls the Data loader and returns its output if successful" do
      expect(Prawn::SVG::Loaders::Data).to receive(:from_url).with(url).and_return("data")
      expect(Prawn::SVG::Loaders::Web).not_to receive(:from_url)

      expect(subject).to eq 'data'
    end

    it "calls the Web loader if the Data loader returns nothing, and returns its output if successful" do
      expect(Prawn::SVG::Loaders::Data).to receive(:from_url).with(url)
      expect(Prawn::SVG::Loaders::Web).to receive(:from_url).with(url).and_return("data")

      expect(subject).to eq 'data'
    end

    it "raises if none of the loaders return any data" do
      expect(Prawn::SVG::Loaders::Data).to receive(:from_url).with(url)
      expect(Prawn::SVG::Loaders::Web).to receive(:from_url).with(url)

      expect { subject }.to raise_error(Prawn::SVG::UrlLoader::Error, /No handler available/)
    end

    context "when caching is enabled" do
      it "caches the result" do
        expect(Prawn::SVG::Loaders::Data).to receive(:from_url).with(url).and_return("data")
        expect(subject).to eq 'data'
        expect(loader.retrieve_from_cache(url)).to eq 'data'
      end
    end

    context "when caching is disabled" do
      let(:enable_cache) { false }

      it "does not cache the result" do
        expect(Prawn::SVG::Loaders::Data).to receive(:from_url).with(url).and_return("data")
        expect(subject).to eq 'data'
        expect(loader.retrieve_from_cache(url)).to be nil
      end
    end

    context "when the cache is populated" do
      before { loader.add_to_cache(url, 'data') }

      it "returns the cached value without calling a loader" do
        expect(Prawn::SVG::Loaders::Data).not_to receive(:from_url)
        expect(Prawn::SVG::Loaders::Web).not_to receive(:from_url)

        expect(subject).to eq 'data'
      end
    end

    context "when web requests are disabled" do
      let(:enable_web) { false }

      it "doesn't use the web loader" do
        expect(Prawn::SVG::Loaders::Data).to receive(:from_url)
        expect(Prawn::SVG::Loaders::Web).not_to receive(:from_url)

        expect { subject }.to raise_error(Prawn::SVG::UrlLoader::Error, /No handler available/)
      end
    end
  end
end
