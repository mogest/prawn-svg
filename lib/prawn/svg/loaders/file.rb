module Prawn::SVG::Loaders
  class File
    attr_reader :root_path

    def initialize(root_path)
      @root_path = ::File.expand_path(root_path)

      raise ArgumentError, "#{root_path} is not a directory" unless Dir.exist?(@root_path)
    end

    def from_url(url)
      uri = build_uri(url)

      if uri && uri.scheme.nil? && uri.path
        path = build_absolute_path(uri.path)
        load_file(path)

      elsif uri && uri.scheme == 'file'
        assert_valid_file_uri!(uri)
        load_file(uri.path)
      end
    end

    private

    def load_file(path)
      path = ::File.expand_path(path)
      assert_valid_path!(path)
      assert_file_exists!(path)
      IO.read(path)
    end

    def build_uri(url)
      begin
        URI(url)
      rescue URI::InvalidURIError
      end
    end

    def assert_valid_path!(path)
      if !path.start_with?("#{root_path}/")
        raise Prawn::SVG::UrlLoader::Error, "file path is not inside the root path of #{root_path}"
      end
    end

    def build_absolute_path(path)
      if path[0] == "/"
        path
      else
        "#{root_path}/#{path}" 
      end
    end

    def assert_valid_file_uri!(uri)
      if uri.host
        raise Prawn::SVG::UrlLoader::Error, "prawn-svg does not suport file: URLs with a host. Your URL probably doesn't start with three slashes, and it should."
      end
    end

    def assert_file_exists!(path)
      if !::File.exist?(path)
        raise Prawn::SVG::UrlLoader::Error, "File #{path} does not exist"
      end
    end
  end
end
