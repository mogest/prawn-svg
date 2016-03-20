require 'spec_helper'

RSpec.describe Prawn::SVG::Loaders::File do
  let(:root_path) { "." }

  subject { Prawn::SVG::Loaders::File.new(root_path).from_url(url) }

  context "when an invalid path is supplied" do
    let(:root_path) { "/does/not/exist" }

    it "raises with an ArgumentError" do
      expect { subject }.to raise_error ArgumentError, /is not a directory/
    end
  end

  context "when a relative path is supplied" do
    let(:url) { "some/relative/./path" }

    it "loads the file" do
      expect(File).to receive(:expand_path).with(".").and_return("/our/root/path")
      expect(File).to receive(:expand_path).with("/our/root/path/some/relative/./path").and_return("/our/root/path/some/relative/path")

      expect(Dir).to receive(:exist?).with("/our/root/path").and_return(true)
      expect(File).to receive(:exist?).with("/our/root/path/some/relative/path").and_return(true)
      expect(IO).to receive(:read).with("/our/root/path/some/relative/path").and_return("data")

      expect(subject).to eq 'data'
    end
  end

  context "when an absolute path without file scheme is supplied" do
    let(:url) { "/some/absolute/./path" }

    it "loads the file" do
      expect(File).to receive(:expand_path).with(".").and_return("/some")
      expect(File).to receive(:expand_path).with(url).and_return("/some/absolute/path")

      expect(Dir).to receive(:exist?).with("/some").and_return(true)
      expect(File).to receive(:exist?).with("/some/absolute/path").and_return(true)
      expect(IO).to receive(:read).with("/some/absolute/path").and_return("data")

      expect(subject).to eq 'data'
    end
  end

  context "when an absolute path with file scheme is supplied" do
    let(:url) { "file:///some/absolute/./path" }

    it "loads the file" do
      expect(File).to receive(:expand_path).with(".").and_return("/some")
      expect(File).to receive(:expand_path).with("/some/absolute/./path").and_return("/some/absolute/path")

      expect(Dir).to receive(:exist?).with("/some").and_return(true)
      expect(File).to receive(:exist?).with("/some/absolute/path").and_return(true)
      expect(IO).to receive(:read).with("/some/absolute/path").and_return("data")

      expect(subject).to eq 'data'
    end
  end

  context "when a path outside of our root is specified" do
    let(:url) { "/some/absolute/./path" }

    it "raises" do
      expect(File).to receive(:expand_path).with(".").and_return("/other")
      expect(File).to receive(:expand_path).with(url).and_return("/some/absolute/path")

      expect(Dir).to receive(:exist?).with("/other").and_return(true)

      expect { subject }.to raise_error Prawn::SVG::UrlLoader::Error, /not inside the root path/
    end
  end

  context "when a file: url with a host is specified" do
    let(:url) { "file://somewhere/somefile" }

    it "raises" do
      expect(File).to receive(:expand_path).with(".").and_return("/other")
      expect(Dir).to receive(:exist?).with("/other").and_return(true)

      expect { subject }.to raise_error Prawn::SVG::UrlLoader::Error, /with a host/
    end
  end
end
