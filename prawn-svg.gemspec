spec = Gem::Specification.new do |s|
  s.name = 'prawn-svg'
  s.version = '0.9.1.10'
  s.summary = "SVG renderer for Prawn PDF library"
  s.description = "SVG renderer for Prawn PDF library"
  s.files = ['README', 'LICENSE'] + Dir['lib/**/*.rb']
  s.require_path = 'lib'
  s.has_rdoc = false
  s.author = "Roger Nesbitt"
  s.email = "roger@seriousorange.com"
  s.homepage = "http://github.com/mogest/prawn-svg"
  s.dependencies << Gem::Dependency.new("prawn", ">= 0.8.4")
  s.dependencies << Gem::Dependency.new("prawn-core", ">= 0.8.4")  
end
