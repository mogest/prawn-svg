#
# A :file_requests callable that reads files from under a root directory.
#
module Prawn::SVG::Requests
  class File
    attr_reader :root_path, :real_root_path

    def initialize(root_path)
      root_path = ::File.path(root_path)
      if root_path.empty?
        raise ArgumentError,
          "An empty string is not a valid root path.  Use '.' if you want the current working directory."
      end

      @root_path = ::File.expand_path(root_path)

      raise ArgumentError, "#{root_path} is not a directory" unless Dir.exist?(@root_path)

      @real_root_path = ::File.realpath(@root_path)
    end

    def call(path)
      # A leading ~ would otherwise be expanded to a home directory.
      path = ::File.expand_path(path.start_with?('~') ? "./#{path}" : path, root_path)
      assert_inside!(path, root_path)
      path = real_path(path)
      assert_inside!(path, real_root_path)
      ::File.binread(path)
    end

    private

    def assert_inside!(path, root)
      # TODO : case sensitive comparison, but it's going to be a bit of a headache
      # making it dependent on whether the file system is case sensitive or not.
      # Leaving it like this until it's a problem for someone.

      raise Prawn::SVG::Requests::Error, "file path is not inside the root path of #{root}" unless path.start_with?("#{root}#{::File::SEPARATOR}")
    end

    def real_path(path)
      real = ::File.realpath(path)
      raise Prawn::SVG::Requests::Error, "#{path} is not a file" unless ::File.file?(real)

      real
    rescue SystemCallError
      raise Prawn::SVG::Requests::Error, "File #{path} does not exist"
    end
  end
end
