module Prawn::SVG::Loaders
  class Data
    REGEXP = %r{\Adata:image/(png|jpeg|svg\+xml);base64(;[a-z0-9]+)*,}i.freeze

    def from_url(url)
      return if url[0..4].downcase != 'data:'

      matches = url.match(REGEXP)
      if matches.nil?
        raise Prawn::SVG::UrlLoader::Error,
          'prawn-svg only supports base64-encoded image/png, image/jpeg, and image/svg+xml data URLs'
      end

      matches.post_match.unpack1('m')
    end
  end
end
