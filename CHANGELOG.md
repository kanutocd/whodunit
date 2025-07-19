# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Features
- **Configurable Data Types**: Support for bigint, integer, string, and UUID column types
- **Smart Detection**: Multi-layered soft-delete detection across popular gems
- **Zero Configuration**: Automatic Rails integration via Railtie
- **Thread Safety**: Built on Rails CurrentAttributes for proper request isolation  
- **Performance**: Zero overhead when no user is set
- **Flexibility**: Manual user management for background jobs and admin actions

### Supported Rails Versions
- Rails 7.0+
- Ruby 3.0+

## [0.1.0] - TBD

### Added
- Initial gem structure and basic functionality