source 'https://rubygems.org'

# Declare your gem's dependencies in prawn-svg.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

unless ENV['MIN_PRAWN'].to_s.empty?
  gem 'css_parser', '1.17.1'
  gem 'prawn', ENV['MIN_PRAWN']
  gem 'rexml', '3.4.2'
end

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

gem 'rake', '~> 13.0'
gem 'rspec', '~> 3.0'
gem 'rubocop', '~> 1.64'
