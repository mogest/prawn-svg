require File.expand_path('lib/prawn/svg/version', __dir__)

Gem::Specification.new do |gem|
  gem.name = 'prawn-svg'
  gem.version = Prawn::SVG::VERSION
  gem.summary = 'SVG renderer for Prawn PDF library'
  gem.description = <<-DESC.strip
    This gem allows you to render SVG directly into a PDF using the 'prawn' gem.  Since PDF is vector-based, you'll get nice scaled graphics if you use SVG instead of an image.
  DESC
  gem.author = 'Mog Nesbitt'
  gem.email = 'mog@seriousorange.com'
  gem.homepage = 'https://github.com/mogest/prawn-svg'
  gem.license = 'MIT'

  gem.files         = Dir['lib/**/*.rb'] + %w[README.md LICENSE]
  gem.require_paths = ['lib']
  gem.metadata      = {
    'rubygems_mfa_required' => 'true',
    'source_code_uri'       => gem.homepage,
    'changelog_uri'         => "#{gem.homepage}/releases",
    'bug_tracker_uri'       => "#{gem.homepage}/issues"
  }

  gem.required_ruby_version = '>= 2.7.0'

  gem.add_dependency 'css_parser', '>= 1.17.1', '< 4'
  gem.add_dependency 'matrix', '~> 0.4.2'
  gem.add_dependency 'prawn', '>= 2.3.0', '< 3'
  gem.add_dependency 'rexml', '>= 3.4.2', '< 4'
  gem.add_dependency 'ssrf_filter', '~> 1.6'
end
