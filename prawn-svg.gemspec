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
  gem.homepage = 'http://github.com/mogest/prawn-svg'
  gem.license = 'MIT'

  gem.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.require_paths = ['lib']
  gem.metadata      = { 'rubygems_mfa_required' => 'true' }

  gem.required_ruby_version = '>= 2.7.0'

  gem.add_runtime_dependency 'css_parser', '~> 1.6'
  gem.add_runtime_dependency 'matrix', '~> 0.4.2'
  gem.add_runtime_dependency 'prawn', '>= 0.11.1', '< 3'
  gem.add_runtime_dependency 'rexml', '>=3.2.0', '< 4'
end
