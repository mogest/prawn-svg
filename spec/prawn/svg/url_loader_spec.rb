require 'spec_helper'

describe Prawn::SVG::UrlLoader do
  let(:loader) { Prawn::SVG::UrlLoader.new(:enable_cache => true, :enable_web => true) }

  describe "#initialize" do
    it "sets options" do
      expect(loader.enable_cache).to be true
      expect(loader.enable_web).to be true
    end
  end

  describe "#valid?" do
    it "knows what a valid URL looks like" do
      expect(loader.valid?("http://valid.example/url")).to be true
      expect(loader.valid?("not/a/valid/url")).to be false
    end

    it "doesn't accept schemes it doesn't like" do
      expect(loader.valid?("mail://valid.example/url")).to be false
    end
  end

  describe "#load" do
    let(:url) { "http://hello/there" }

    it "loads an HTTP URL and saves to the cache" do
      o = double(:read => "hello!")
      loader.should_receive(:open).with(url).and_return(o)
      
      expect(loader.load(url)).to eq "hello!"
      expect(loader.url_cache[url]).to eq "hello!"
    end

    it "loads an HTTP URL from the cache without calling open" do
      loader.url_cache[url] = "hello"
      loader.should_not_receive(:open)
      expect(loader.load(url)).to eq "hello"
    end

    it "loads a data URL" do
      loader.should_not_receive(:open)
      expect(loader.load("data:image/png;base64,aGVsbG8=")).to eq "hello"
    end
  end
end
