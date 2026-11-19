require 'spec_helper'
require 'tmpdir'

RSpec.describe Prawn::SVG::Loaders::File do
  let(:file_requests) { ->(path) { "read #{path}" } }
  let(:file_loader) { Prawn::SVG::Loaders::File.new(file_requests) }
  subject { file_loader.from_url(url) }

  context 'when file requests are disabled' do
    let(:file_requests) { false }
    let(:url) { 'sub/path%20name' }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::Requests::Error, /file requests are disabled/
    end
  end

  context 'when file_requests is not false, a root path or a callable' do
    let(:file_requests) { :yes }

    it 'raises an ArgumentError' do
      expect { file_loader }.to raise_error ArgumentError, /:file_requests must be/
    end
  end

  [String, Pathname].each do |klass|
    context "when file_requests is a root path #{klass}" do
      let(:file_requests) { klass.new(@dir) }
      let(:url) { 'path%20name' }

      around do |example|
        Dir.mktmpdir do |dir|
          @dir = dir
          File.write("#{dir}/path name", 'data')
          example.run
        end
      end

      it 'reads files from under it' do
        expect(subject).to eq 'data'
      end
    end
  end

  it 'passes the callable the decoded path' do
    expect(file_loader.from_url('sub/./path%20name')).to eq 'read sub/./path name'
    expect(file_loader.from_url('/abs/path%20name')).to eq 'read /abs/path name'
    expect(file_loader.from_url('file:///abs/path%20name')).to eq 'read /abs/path name'
  end

  it 'raises a TypeError if the callable returns something other than a String' do
    loader = Prawn::SVG::Loaders::File.new(->(_path) {})
    expect { loader.from_url('x') }.to raise_error TypeError, /returned NilClass/
  end

  context 'when the path contains a null byte' do
    let(:url) { 'a%00b' }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::Requests::Error, /null byte/
    end
  end

  context 'when a file: url with a host is specified' do
    let(:url) { 'file://somewhere/somefile' }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::Requests::Error, /with a host/
    end
  end

  context 'when a file: url with a relative path is specified' do
    let(:url) { 'file:sub/path%20name' }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::Requests::Error, /absolute path/
    end
  end

  context "when we're running on Windows" do
    let(:url) { 'file:///c:/path/to/file.png' }

    it "automatically fixes up URI's misparsing of Windows file paths" do
      allow(file_loader).to receive(:windows?).and_return true
      expect(subject).to eq 'read c:/path/to/file.png'
    end
  end

  context 'when a URL can be split but not built, such as mailto:x' do
    let(:url) { 'mailto:x' }

    it 'returns nil' do
      expect(subject).to be_nil
    end
  end
end
