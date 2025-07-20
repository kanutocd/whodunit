# frozen_string_literal: true

require_relative "lib/whodunit/version"

Gem::Specification.new do |spec|
  spec.name = "whodunit"
  spec.version = Whodunit::VERSION
  spec.authors = ["Ken C. Demanawa"]
  spec.email = ["kenneth.c.demanawa@gmail.com"]

  spec.summary = "Lightweight creator/updater/deleter tracking for ActiveRecord models"
  spec.description = "A lightweight Rails gem that provides simple auditing by tracking who created, updated, and " \
                     "deleted ActiveRecord models. Features smart soft-delete detection and zero performance overhead."
  spec.homepage = "https://github.com/kanutocd/whodunit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/kanutocd/whodunit.git"
  spec.metadata["changelog_uri"] = "https://github.com/kanutocd/whodunit/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/kanutocd/whodunit/issues"
  spec.metadata["documentation_uri"] = "https://github.com/kanutocd/whodunit/blob/main/README.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "activerecord", ">= 6.1"
  spec.add_dependency "activesupport", ">= 6.1"

  # Development dependencies
  spec.add_development_dependency "bundler-audit", "~> 0.9.2"
  spec.add_development_dependency "irb", "~> 1.15"
  spec.add_development_dependency "kramdown", ">= 2.5"
  spec.add_development_dependency "rake", ">= 13.3"
  spec.add_development_dependency "rspec", ">= 3.13"
  spec.add_development_dependency "rubocop", ">= 1.78"
  spec.add_development_dependency "rubocop-performance", ">= 1.25"
  spec.add_development_dependency "rubocop-rspec", ">= 3.6"
  spec.add_development_dependency "simplecov", ">= 0.22.0"
  spec.add_development_dependency "simplecov-cobertura", ">= 3.0"
  spec.add_development_dependency "yard", ">= 0.9.37"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
