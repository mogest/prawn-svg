require 'addressable/uri'

#
# Load a file from disk.
#
# WINDOWS
# =======
# Windows is supported, but must use URLs in the modern structure like:
#   file:///x:/path/to/the/file.png
# or as a relative path:
#   directory/file.png
# or as an absolute path from the current drive:
#   /path/to/the/file.png
#
# Ruby's URI parser does not like backslashes, nor can it handle filenames as URLs starting
# with a drive letter as it thinks you're giving it a scheme.
#
# URL ENCODING
# ============
# This module assumes the URL that is passed in has been URL-encoded.  If for some reason
# you're passing in a filename that hasn't been taken from an XML document's attribute,
# you will want to URL encode it before you pass it in.
#
module Prawn::SVG::Loaders
  class File
    attr_reader :allowed_file_path_fn

    def initialize(allowed_file_path_fn)
      @allowed_file_path_fn = allowed_file_path_fn
    end

    def from_url(url, binary:)
      uri = build_uri(url)

      if uri && uri.scheme.nil? && uri.path
        load_file(uri.path, binary: binary)

      elsif uri && uri.scheme == 'file'
        assert_valid_file_uri!(uri)
        path = windows? ? fix_windows_path(uri.path) : uri.path
        load_file(path, binary: binary)
      end
    end

    private

    def load_file(path, binary:)
      path = Addressable::URI.unencode(path)
      path = build_absolute_and_expand_path(path)
      assert_valid_path!(path)
      assert_file_exists!(path)

      if binary
        ::File.binread(path)
      else
        ::File.read(path)
      end
    end

    def build_uri(url)
      URI(url)
    rescue URI::InvalidURIError
    end

    def assert_valid_path!(path)
      unless allowed_file_path_fn.call(path)
        raise Prawn::SVG::UrlLoader::Error,
          'file path does not pass validation of :enable_file_requests_with_root or :allowed_file_path_fn'
      end
    end

    def build_absolute_and_expand_path(path)
      ::File.expand_path(path, root_path)
    end

    def assert_valid_file_uri!(uri)
      unless uri.host.nil? || uri.host.empty?
        raise Prawn::SVG::UrlLoader::Error,
          "prawn-svg does not suport file: URLs with a host. Your URL probably doesn't start with three slashes, " \
          'and it should.'
      end
    end

    def assert_file_exists!(path)
      raise Prawn::SVG::UrlLoader::Error, "File #{path} does not exist" unless ::File.exist?(path)
    end

    def fix_windows_path(path)
      if path.match(%r{\A/[a-z]:/}i)
        path[1..]
      else
        path
      end
    end

    def windows?
      !!(RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/)
    end
  end
end
