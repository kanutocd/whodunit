# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

# Load YARD tasks
begin
  require "yard"
  YARD::Rake::YardocTask.new do |t|
    t.files = ["lib/**/*.rb"]
    t.options = %w[--output-dir doc --markup markdown]
  end
rescue LoadError
  # YARD not available
end

task default: :spec
