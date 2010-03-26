require 'spec/rake/spectask'
require 'rake/rdoctask'

task :default => :spec

Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = Dir.glob('spec/**/*_spec.rb')
end

Rake::RDocTask.new do |rdoc|
	rdoc.main     = "README"
	rdoc.rdoc_dir = "doc/html"
	rdoc.title    = "prawn-svg documentation"
	rdoc.rdoc_files.include("README", "LICENSE", "lib/")
end
