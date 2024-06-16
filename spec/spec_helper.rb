require 'bundler'
Bundler.require(:default, :development)

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |f| require f }

module Support
  def flatten_calls(_calls)
    [].tap do |flattened_calls|
      add = lambda do |local_calls|
        local_calls.each do |call|
          flattened_calls << call[0..2]
          add.call call[3]
        end
      end

      add.call element.base_calls
    end
  end

  def fake_state
    state = Prawn::SVG::State.new
    state.viewport_sizing = document.sizing if defined?(document)
    state
  end
end

RSpec.configure do |config|
  config.mock_with :rspec do |c|
    c.syntax = %i[should expect]
  end

  config.expect_with :rspec do |c|
    c.syntax = %i[should expect]
  end

  config.include Support

  config.before(:suite) do
    # calculate the MD5 of all files in spec/sample_output and store in a hash
    $hashes = {}

    Dir["#{File.dirname(__FILE__)}/sample_output/*.pdf"].each do |file|
      hash = Digest::MD5.file(file).hexdigest
      $hashes[file] = hash
    end
  end

  config.after(:suite) do
    # print out the PDFs that have changed
    changed = $hashes.reject do |file, hash|
      new_hash = Digest::MD5.file(file).hexdigest
      new_hash == hash
    end

    if changed.any?
      puts "\nThese PDFs have changed since the last test run:"
      cwd = "#{Dir.pwd}/"
      changed.each_key { |file| puts "  #{file.sub(cwd, '')}" }
    end
  end
end
