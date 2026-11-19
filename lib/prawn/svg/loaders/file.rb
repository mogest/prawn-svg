require 'addressable/uri'

#
# Handles file: URLs and relative paths, passing the decoded path to the :file_requests callable.
#
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
module Prawn::SVG::Loaders
  class File
    def initialize(file_requests)
      file_requests = Prawn::SVG::Requests::File.new(file_requests) if file_requests.is_a?(String) || file_requests.respond_to?(:to_path)
      raise ArgumentError, ':file_requests must be false, a root path or a callable' unless [false, nil].include?(file_requests) || file_requests.respond_to?(:call)

      @request_fn = file_requests
    end

    def from_url(url)
      uri = build_uri(url)
      return unless uri && [nil, 'file'].include?(uri.scheme)

      raise Prawn::SVG::Requests::Error, 'file requests are disabled; see the :file_requests option' unless @request_fn

      path = Addressable::URI.unencode(uri.scheme ? file_uri_path(uri) : uri.path)
      raise Prawn::SVG::Requests::Error, 'file path contains a null byte' if path.include?("\0")

      perform_request(path)
    end

    private

    def build_uri(url)
      URI(url)
    rescue URI::Error
    end

    def file_uri_path(uri)
      unless uri.host.nil? || uri.host.empty?
        raise Prawn::SVG::Requests::Error,
          "prawn-svg does not support file: URLs with a host. Your URL probably doesn't start with three slashes, and it should."
      end

      raise Prawn::SVG::Requests::Error, 'file: URLs must have an absolute path' unless uri.path

      windows? && uri.path.match?(%r{\A/[a-z]:/}i) ? uri.path[1..] : uri.path
    end

    def perform_request(path)
      data = @request_fn.call(path)
      raise TypeError, "file request returned #{data.class} instead of a String" unless data.is_a?(String)

      data
    end

    def windows?
      !!(RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/)
    end
  end
end
