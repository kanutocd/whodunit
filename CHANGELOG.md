# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-01-20

### Added

- New `whodunit install` CLI command to generate configuration initializer
- Per-model configuration override capability via `whodunit_config` block
- Column enabling/disabling - set individual columns to `nil` to disable them
- Configuration validation to prevent disabling both creator and updater columns
- Comprehensive generator with Rails app detection and safety prompts
- Enhanced YARD documentation reflecting simplified architecture

### Changed

- **BREAKING**: `soft_delete_column` now defaults to `nil` instead of `:deleted_at`
- **BREAKING**: Removed automatic soft-delete detection - now purely configuration-based
- **BREAKING**: Simplified `being_soft_deleted?` logic to check only configured column
- Migration helpers now respect column enabling/disabling configuration
- Updated all documentation to reflect simplified, configuration-based approach
- Improved test infrastructure with better configuration isolation

### Removed

- **BREAKING**: `SoftDeleteDetector` class and all auto-detection logic
- **BREAKING**: `SOFT_DELETE_COLUMNS` constant and pattern-matching detection
- Complex database schema introspection for soft-delete detection

### Performance

- Eliminated expensive auto-detection queries during model initialization
- Reduced computational overhead by trusting user configuration
- Simplified callback and association setup based on explicit configuration

## [0.1.0] - 2025-01-15

### Added

- Initial release of Whodunit gem
- Thread-safe user context with `Whodunit::Current`
- Smart soft-delete detection for multiple gems (Discard, Paranoia, ActsAsParanoid)
- Automatic creator/updater/deleter tracking via `Whodunit::Stampable`
- Database migration helpers with configurable data types
- Rails controller integration with automatic user detection
- Comprehensive test suite with 93.4% coverage
- YARD documentation for API reference
- RuboCop integration for code style enforcement
- SimpleCov integration for test coverage tracking
- Github CI workflow with ruby version matrix strategy for 3.1.1=>7.2, 3.2.0=>7.2, 3.3.0=>8.0.2, 3.4.4=>edge
- Github CD (Release) workflow on version release and manual via workflow dispatch dry-run support
- Documentation deployment Github pages workflow/pipeline

### Features

- **Configurable Data Types**: Support for bigint, integer, string, and UUID column types
- **Smart Detection**: Multi-layered soft-delete detection across popular gems
- **Zero Configuration**: Automatic Rails integration via Railtie
- **Thread Safety**: Built on Rails CurrentAttributes for proper request isolation
- **Performance**: Zero overhead when no user is set
- **Flexibility**: Manual user management for background jobs and admin actions

### Supported Ruby, and Ruby on Rails Versions

- Rails 7.2+
- Ruby 3.1+
