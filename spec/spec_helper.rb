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

# bundler/setup locks the load path to Gemfile.lock-resolved gems.  In a
# full Bundler environment (CI, `bundle exec rspec`) this is fine.  When
# running specs directly with the system Ruby (no bundle exec) the locked
# versions may not be available, so we silently skip the setup – the gems
# we actually need (activerecord, activesupport, rspec, simplecov, sqlite3)
# are required individually below.
begin
  require "bundler/setup"
rescue LoadError, Bundler::GemNotFound
  # Running outside of bundle exec – fall through
end

require "active_record"
require "active_support/all"
require "logger"
require "whodunit"

# Load test support files (includes schema creation + model definitions)
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

# Store original configuration values to prevent test pollution.
# Keep in sync with every mattr_accessor in lib/whodunit.rb.
ORIGINAL_WHODUNIT_CONFIG = {
  user_class: "User",
  creator_column: :creator_id,
  updater_column: :updater_id,
  deleter_column: :deleter_id,
  soft_delete_column: nil,
  auto_inject_whodunit_stamps: true,
  column_data_type: :bigint,
  creator_column_type: nil,
  updater_column_type: nil,
  deleter_column_type: nil,
  auto_setup_reverse_associations: true,
  reverse_association_prefix: "",
  reverse_association_suffix: ""
}.freeze

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

  config.before do
    # Mocks the valid column options in  test block to allow or disallow custom ones
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ActiveRecord::ConnectionAdapters::TableDefinition)
      .to receive(:valid_column_definition_options).and_return(%i[imit default null precision scale comment collation primary_key])
    # rubocop:enable RSpec/AnyInstance
  end

  # Wrap each example in a DB transaction so AR tests don't bleed state.
  # Uses the real AR connection established in spec/support/test_models.rb.
  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end

  # Clean up after each test – reset Whodunit configuration and current user
  config.after do
    Whodunit::Current.reset

    # Restore original configuration to prevent test pollution
    ORIGINAL_WHODUNIT_CONFIG.each do |key, value|
      Whodunit.public_send(:"#{key}=", value)
    end

    # Clear registered models so model-registration specs start clean
    Whodunit.registered_models.clear
  end
end
