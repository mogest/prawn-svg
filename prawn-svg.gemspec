# -*- encoding: utf-8 -*-
require File.expand_path('../lib/prawn/svg/version', __FILE__)

spec = Gem::Specification.new do |gem|
  gem.name = 'prawn-svg'
  gem.version = Prawn::Svg::VERSION
  gem.summary = "SVG renderer for Prawn PDF library"
  gem.description = "SVG renderer for Prawn PDF library"
  gem.has_rdoc = false
  gem.author = "Roger Nesbitt"
  gem.email = "roger@seriousorange.com"
  gem.homepage = "http://github.com/mogest/prawn-svg"
  
  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "prawn-svg"
  gem.require_paths = ["lib"]
  
  gem.add_dependency "prawn", ">= 0.8.4"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rake"
end
