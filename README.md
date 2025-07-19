# Whodunit

Lightweight creator/updater/deleter tracking for Rails ActiveRecord models.

> **Fun Fact**: The term "whodunit" was coined by literary critic Donald Gordon in 1930 when reviewing a murder mystery novel for _American News of Books_. He described Milward Kennedy's _Half Mast Murder_ as "a satisfactory whodunit" - the first recorded use of this now-famous term for mystery stories! _([Source: Wikipedia](https://en.wikipedia.org/wiki/Whodunit))_

## Overview

Whodunit provides simple auditing for Rails applications by tracking who created, updated, and deleted records. Unlike heavyweight solutions like PaperTrail or Audited, Whodunit focuses solely on user tracking with zero performance overhead.

## Requirements

- Ruby 3.1.0+ (tested on 3.1.0, 3.2.0, 3.3.0, 3.4). See the [the ruby-version matrix strategy of the CI workflow](https://github.com/kanutocd/whodunit/blob/main/.github/workflows/ci.yml#L15).
- Rails 6.1+ (tested on 6.1, 7.0, 7.1, 8.0)
- ActiveRecord for database operations

## Features

- **Lightweight**: Only tracks user IDs, no change history or versioning
- **Smart Soft-Delete Detection**: Automatically detects Discard, Paranoia, and custom soft-delete implementations
- **Thread-Safe**: Uses Rails `CurrentAttributes` pattern for user context
- **Zero Dependencies**: Only requires Rails 6.1+
- **Performance Focused**: No default scopes or method overrides

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'whodunit'
```

And then execute:

    $ bundle install

## Quick Start

### 1. Add Stamp Columns

Generate a migration to add the tracking columns:

```ruby
class AddStampsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_whodunit_stamps :users  # Adds creator_id, updater_id columns
  end
end
```

For models with soft-delete, deleter tracking is automatically detected:

```ruby
class AddStampsToDocuments < ActiveRecord::Migration[7.0]
  def change
    add_whodunit_stamps :documents  # Adds creator_id, updater_id, deleter_id (if soft-delete detected)
  end
end
```

### 2. Include Stampable in Models

```ruby
class User < ApplicationRecord
  include Whodunit::Stampable
end

class Document < ApplicationRecord
  include Discard::Model  # or acts_as_paranoid, etc.
  include Whodunit::Stampable  # Automatically detects soft-delete!
end
```

### 3. Set Up Controller Integration

```ruby
class ApplicationController < ActionController::Base
  # Whodunit::ControllerMethods is automatically included via Railtie
  # It will automatically set the current user for stamping
end
```

## Usage

Once set up, stamping happens automatically:

```ruby
# Creating records
user = User.create!(name: "Ken")
# => Sets user.creator_id to current_user.id

# Updating records
user.update!(name: "Sophia")
# => Sets user.updater_id to current_user.id

# Soft deleting (if soft-delete gem is detected)
document.discard
# => Sets document.deleter_id to current_user.id
```

Access the stamp information via associations:

```ruby
user.creator   # => User who created this record
user.updater   # => User who last updated this record
user.deleter   # => User who deleted this record (if soft-delete enabled)
```

## Smart Soft-Delete Detection

Whodunit automatically detects popular soft-delete solutions:

- **Discard** (`gem 'discard'`)
- **Paranoia** (`gem 'paranoia'`)
- **ActsAsParanoid** (`gem 'acts_as_paranoid'`)
- **Custom implementations** with timestamp columns like `deleted_at`, `discarded_at`, etc.

## Configuration

```ruby
# config/initializers/whodunit.rb
Whodunit.configure do |config|
  config.user_class = 'Account'             # Default: 'User'
  config.creator_column = :created_by_id    # Default: :creator_id
  config.updater_column = :updated_by_id    # Default: :updater_id
  config.deleter_column = :deleted_by_id    # Default: :deleter_id
  config.auto_detect_soft_delete = false   # Default: true

  # Column data type configuration
  config.column_data_type = :integer       # Default: :bigint (applies to all columns)
  config.creator_column_type = :string     # Default: nil (uses column_data_type)
  config.updater_column_type = :uuid       # Default: nil (uses column_data_type)
  config.deleter_column_type = :integer    # Default: nil (uses column_data_type)
end
```

### Data Type Configuration

By default, all stamp columns use `:bigint` data type. You can customize this in several ways:

- **Global**: Set `column_data_type` to change the default for all columns
- **Individual**: Set specific column types to override the global default
- **Per-migration**: Override types on a per-migration basis (see Migration Helpers)

## Manual User Setting

For background jobs, tests, or special scenarios:

```ruby
# Temporarily set user
Whodunit::Current.user = User.find(123)
MyModel.create!(name: "test")  # Will be stamped with user 123

# Within a block
controller.with_whodunit_user(admin_user) do
  Document.create!(title: "Admin Document")
end

# Disable stamping temporarily
controller.without_whodunit_user do
  Document.create!(title: "System Document")  # No stamps
end
```

## Migration Helpers

```ruby
# Basic usage (uses configured data types)
class CreatePosts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts do |t|
      t.string :title
      t.whodunit_stamps  # Adds creator_id, updater_id with configured types
      t.timestamps
    end
  end
end

# Custom data types per migration
class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :email
      t.whodunit_stamps include_deleter: true,
                        creator_type: :uuid,
                        updater_type: :string,
                        deleter_type: :integer
      t.timestamps
    end
  end
end

# Add to existing table with custom types
class AddStampsToExistingTable < ActiveRecord::Migration[7.0]
  def change
    add_whodunit_stamps :existing_table,
                        include_deleter: :auto,
                        creator_type: :string,
                        updater_type: :uuid
  end
end

# Mixed approach - some custom, some default
class CreateDocuments < ActiveRecord::Migration[7.0]
  def change
    create_table :documents do |t|
      t.string :title
      t.whodunit_stamps creator_type: :uuid  # Only override creator, others use defaults
      t.timestamps
    end
  end
end
```

### Data Type Options

Common data types you can use:

- `:bigint` (default) - 64-bit integer, suitable for large user bases
- `:integer` - 32-bit integer, suitable for smaller applications
- `:string` - For string-based user identifiers
- `:uuid` - For UUID-based user systems
- Any other Rails column type

## Controller Methods

Skip stamping for specific actions:

```ruby
class ApiController < ApplicationController
  skip_whodunit_for :index, :show
end
```

Only stamp specific actions:

```ruby
class ReadOnlyController < ApplicationController
  whodunit_only_for :create, :update, :destroy
end
```

## Thread Safety

Whodunit uses Rails `CurrentAttributes` for thread-safe user context:

```ruby
# Each thread maintains its own user context
Thread.new { Whodunit::Current.user = user1; create_records }
Thread.new { Whodunit::Current.user = user2; create_records }
```

## Testing

In your tests, you can set the user context:

```ruby
# RSpec
before do
  Whodunit::Current.user = create(:user)
end

# Or within specific tests
it "tracks creator" do
  user = create(:user)
  Whodunit::Current.user = user

  post = create(:post)
  expect(post.creator).to eq(user)
end
```

## Comparisons

| Feature               | Whodunit | PaperTrail | Audited |
| --------------------- | -------- | ---------- | ------- |
| User tracking         | ✅       | ✅         | ✅      |
| Change history        | ❌       | ✅         | ✅      |
| Performance overhead  | None     | High       | Medium  |
| Soft-delete detection | ✅       | ❌         | ❌      |
| Setup complexity      | Low      | Medium     | Medium  |

## Documentation

Complete API documentation is available at: **[https://kanutocd.github.io/whodunit](https://kanutocd.github.io/whodunit)**

The documentation includes:

- Comprehensive API reference with examples
- Configuration options and their defaults
- Migration helper methods
- Controller integration patterns
- Advanced usage scenarios

To generate documentation locally:

```bash
bundle exec yard doc
open doc/index.html
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec gem build whodunit.gemspec && gem install ./whodunit-*.gem`.

### Testing

```bash
# Run all tests
bundle exec rspec

# Run tests with coverage
COVERAGE=true bundle exec rspec

# Run RuboCop
bundle exec rubocop

# Run security audit
bundle exec bundle audit check --update

# Generate documentation
bundle exec yard doc
```

### Release Process

The gem uses automated CI/CD workflows:

- **CI**: Automatically runs tests, linting, and security checks on every push and PR
- **Release**: Supports both automatic releases (on GitHub release creation) and manual releases via workflow dispatch
- **Documentation**: Automatically deploys API documentation to GitHub Pages

To perform a release:

1. **Dry Run**: Test the release process without publishing

   ```bash
   # Via GitHub Actions UI: Run "Release" workflow with dry_run=true
   ```

2. **Create Release**:

   ```bash
   # Update version in lib/whodunit/version.rb
   # Commit and push changes
   # Create a GitHub release via UI or CLI
   gh release create v0.1.0 --title "Release v0.1.0" --notes "Release notes here"
   ```

3. **Manual Release** (if needed):
   ```bash
   # Via GitHub Actions UI: Run "Release" workflow with dry_run=false
   ```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kanutocd/whodunit.

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`bundle exec rspec`)
6. Run RuboCop and fix any style issues (`bundle exec rubocop`)
7. Update documentation if needed
8. Commit your changes (`git commit -am 'Add amazing feature'`)
9. Push to the branch (`git push origin feature/amazing-feature`)
10. Open a Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
