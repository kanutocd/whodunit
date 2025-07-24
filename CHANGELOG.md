# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2025-01-24

### Added

- **Automatic Reverse Associations**: When models include `Whodunit::Stampable`, reverse associations are automatically created on the user class (e.g., `user.created_posts`, `user.updated_comments`, `user.deleted_documents`)
- **Model Registry System**: Tracks models that include Stampable for automatic reverse association setup
- **Per-Model Reverse Association Control**: Models can disable reverse associations with `disable_whodunit_reverse_associations!`
- **Reverse Association Configuration**: Global configuration options including `auto_setup_reverse_associations`, `reverse_association_prefix`, and `reverse_association_suffix`
- **Smart Model Capability Detection**: Automatically detects which associations to create based on model capabilities (creator, updater, deleter, soft-delete)
- **Custom Column Support**: Reverse associations respect per-model custom column configurations
- **Manual Setup Methods**: `setup_whodunit_reverse_associations!` and `setup_all_reverse_associations` for manual control

### Changed

- **Enhanced Stampable Module**: Now automatically registers models for reverse association setup when included
- **Improved Configuration**: Extended main configuration module with reverse association settings
- **Better Association Management**: Prevents duplicate associations and handles edge cases gracefully

### Features

- **Zero Configuration**: Reverse associations work automatically with sensible defaults
- **Thread Safe**: Built on existing thread-safe architecture
- **Flexible Naming**: Configurable prefixes and suffixes for association names
- **Comprehensive Testing**: Full test coverage for all reverse association functionality
- **RuboCop Compliant**: All code follows project style guidelines

## [0.2.1] - 2025-01-21

### Added

- **ApplicationRecord Integration**: `whodunit install` now prompts to automatically add `Whodunit::Stampable` to `ApplicationRecord` for convenient all-model stamping
- **Enhanced Configuration Template**: Detailed explanations and examples for each configuration option in generated initializer
- **Post-install Message**: Helpful instructions displayed after gem installation via `bundle add whodunit`
- **Comprehensive Test Coverage**: Full test suite for ApplicationRecord integration with edge case handling

### Changed

- **Improved CLI Experience**: More user-friendly prompts and messages throughout the installation process
- **Better Documentation**: Updated README with corrected installation commands and new ApplicationRecord feature
- **Code Organization**: Extracted ApplicationRecord integration logic into separate module for better maintainability

### Fixed

- **Gemspec Consistency**: Corrected post-install message to show `whodunit install` instead of incorrect Rails generator command
- **RuboCop Compliance**: Fixed all style issues and reduced complexity across codebase

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
