# frozen_string_literal: true

# Start SimpleCov first
require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"

  # Require 100% coverage (temporarily set to 93 while working towards 100%)
  minimum_coverage 93

  # Coverage output directory
  coverage_dir "coverage"

  # Enable branch coverage for better analysis
  enable_coverage :branch

  # Generate multiple formats for CI
  if ENV["CI"] || ENV["COVERAGE"]
    require "simplecov-cobertura"
    SimpleCov.formatters = [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::CoberturaFormatter
    ]
  end

  # Exclude generated or boilerplate files
  add_filter "lib/whodunit/version.rb" # Simple version constant
end

require "bundler/setup"
require "whodunit"

# Load test support files
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Test ordering
  config.order = :random
  Kernel.srand config.seed

  # Filter out any specs with :focus tag unless specifically running them
  config.filter_run_when_matching :focus

  # Clean up after each test
  config.after do
    Whodunit::Current.reset
  end
end
