require 'spec_helper'
require 'tmpdir'

RSpec.describe Prawn::SVG::Requests::File do
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
  let(:file_request) { described_class.new(root) }
  subject { file_request.call(path) }

  context 'when an invalid root path is supplied' do
    let(:root) { '/does/not/exist' }

    it 'raises with an ArgumentError' do
      expect { file_request }.to raise_error ArgumentError, /is not a directory/
    end
  end

  context 'when an empty root path is supplied' do
    let(:root) { '' }

    it 'raises with an ArgumentError' do
      expect { file_request }.to raise_error ArgumentError, /empty string/
    end
  end

  context 'when the root path starts with ~' do
    let(:root) { '~' }

    it 'expands it to the home directory' do
      expect(file_request.root_path).to eq Dir.home
    end
  end

  context 'when the root path is an empty directory given as a Pathname' do
    let(:root) { Pathname.new("#{@dir}/root/empty").tap(&:mkdir) }

    it 'accepts it' do
      expect(file_request.root_path).to eq "#{@dir}/root/empty"
    end
  end

  context 'when a relative path is supplied' do
    let(:path) { 'sub/./path name' }

    it 'loads the file' do
      expect(subject).to eq 'data'
    end
  end

  context 'when an absolute path is supplied' do
    let(:path) { "#{root}/sub/./path name" }

    it 'loads the file' do
      expect(subject).to eq 'data'
    end
  end

  context 'when the root path is reached through a symlink' do
    let(:root) { "#{@dir}/link" }
    let(:path) { "#{root}/sub/path name" }

    before { File.symlink("#{@dir}/root", root) }

    it 'loads the file' do
      expect(subject).to eq 'data'
    end
  end

  context 'when the root path is the filesystem root' do
    let(:root) { '/' }
    let(:path) { "#{@dir}/secret" }

    it 'loads the file' do
      expect(subject).to eq 'secret'
    end
  end

  context 'when a path outside of our root is specified' do
    let(:path) { '../secret' }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::Requests::Error, /not inside the root path/
    end
  end

  context 'when a path is in a sibling directory that starts with the root path' do
    let(:path) { "#{root}x/file" }

    before do
      Dir.mkdir("#{root}x")
      File.write(path, 'data')
    end

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::Requests::Error, /not inside the root path/
    end
  end

  context 'when a symlink inside the root points outside it' do
    let(:path) { 'link' }

    before { File.symlink("#{@dir}/secret", "#{root}/link") }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::Requests::Error, /not inside the root path/
    end
  end

  context 'when a relative path starts with ~' do
    let(:path) { '~nosuchuser/x' }

    it 'treats it as a path under the root' do
      expect { subject }.to raise_error Prawn::SVG::Requests::Error, %r{root/~nosuchuser/x does not exist}
    end
  end

  context 'when the file does not exist' do
    let(:path) { 'missing' }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::Requests::Error, /does not exist/
    end
  end

  context 'when the path is a directory' do
    let(:path) { 'sub' }

    it 'raises' do
      expect { subject }.to raise_error Prawn::SVG::Requests::Error, /is not a file/
    end
  end

  context "when we're running on Windows with a drive letter path" do
    let(:path) { 'c:/path/to/file.png' }

    it 'resolves it against the root' do
      allow(file_request).to receive_messages(root_path: 'c:/full', real_root_path: 'c:/full')
      expect(File).to receive(:expand_path).with('c:/path/to/file.png', 'c:/full').and_return('c:/full/path/to/file.png')
      expect(File).to receive(:realpath).with('c:/full/path/to/file.png').and_return('c:/full/path/to/file.png')
      expect(File).to receive(:file?).with('c:/full/path/to/file.png').and_return(true)
      expect(File).to receive(:binread).with('c:/full/path/to/file.png').and_return('data')

      expect(subject).to eq 'data'
    end
  end
end
