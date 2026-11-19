require 'spec_helper'
require 'tmpdir'

RSpec.describe Prawn::SVG::Loaders::File do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = File.realpath(dir)
      Dir.mkdir("#{@dir}/root")
      Dir.mkdir("#{@dir}/root/sub")
      File.write("#{@dir}/root/sub/path name", 'data')
      File.write("#{@dir}/secret", 'secret')
      example.run
    end
  end

  let(:root) { "#{@dir}/root" }
  let(:file_loader) { Prawn::SVG::Loaders::File.new(root) }
  subject { file_loader.from_url(url) }

  context 'when an invalid root path is supplied' do
    let(:root) { '/does/not/exist' }

    it 'raises with an ArgumentError' do
      expect { file_loader }.to raise_error ArgumentError, /is not a directory/
    end
  end

  context 'when the root path starts with ~' do
    let(:root) { '~' }

    it 'expands it to the home directory' do
      expect(file_loader.root_path).to eq Dir.home
    end
  end

  context 'when a relative path is supplied' do
    let(:url) { 'sub/./path%20name' }

    it 'loads the file' do
      expect(subject).to eq 'data'
    end
  end

  context 'when an absolute path without file scheme is supplied' do
    let(:url) { "#{root}/sub/./path%20name" }

    it 'loads the file' do
      expect(subject).to eq 'data'
    end
  end

  context 'when an absolute path with file scheme is supplied' do
    let(:url) { "file://#{root}/sub/./path%20name" }

    it 'loads the file' do
      expect(subject).to eq 'data'
    end
  end

  context 'when the root path is reached through a symlink' do
    let(:root) { "#{@dir}/link" }
    let(:url) { "#{root}/sub/path%20name" }

    before { File.symlink("#{@dir}/root", root) }

    it 'loads the file' do
      expect(subject).to eq 'data'
    end
  end

  context 'when a path outside of our root is specified' do
    let(:url) { '../secret' }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::UrlLoader::Error, /not inside the root path/
    end
  end

  context 'when a symlink inside the root points outside it' do
    let(:url) { 'link' }

    before { File.symlink("#{@dir}/secret", "#{root}/link") }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::UrlLoader::Error, /not inside the root path/
    end
  end

  context 'when the file does not exist' do
    let(:url) { 'missing' }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::UrlLoader::Error, /does not exist/
    end
  end

  context 'when the path is a directory' do
    let(:url) { 'sub' }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::UrlLoader::Error, /is not a file/
    end
  end

  context 'when the path contains a null byte' do
    let(:url) { 'a%00b' }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::UrlLoader::Error, /null byte/
    end
  end

  context 'when a file: url with a host is specified' do
    let(:url) { 'file://somewhere/somefile' }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::UrlLoader::Error, /with a host/
    end
  end

  context 'when a file: url with a relative path is specified' do
    let(:url) { 'file:sub/path%20name' }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::UrlLoader::Error, /absolute path/
    end
  end

  context "when we're running on Windows" do
    let(:url) { 'file:///c:/path/to/file.png' }

    it "automatically fixes up URI's misparsing of Windows file paths and loads the file" do
      allow(file_loader).to receive(:windows?).and_return true
      allow(file_loader).to receive_messages(root_path: 'c:/full', real_root_path: 'c:/full')
      expect(File).to receive(:expand_path).with('c:/path/to/file.png', 'c:/full').and_return('c:/full/path/to/file.png')
      expect(File).to receive(:realpath).with('c:/full/path/to/file.png').and_return('c:/full/path/to/file.png')
      expect(File).to receive(:file?).with('c:/full/path/to/file.png').and_return(true)
      expect(File).to receive(:binread).with('c:/full/path/to/file.png').and_return('data')

      expect(subject).to eq 'data'
    end
  end

  context 'when a URL can be split but not built, such as mailto:x' do
    let(:url) { 'mailto:x' }

    it 'returns nil' do
      expect(subject).to be_nil
    end
  end
end
