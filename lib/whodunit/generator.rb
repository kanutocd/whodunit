# frozen_string_literal: true

require "fileutils"
require_relative "generator/application_record_integration"

module Whodunit
  # Generator for creating Whodunit configuration files
  class Generator
    INITIALIZER_CONTENT = <<~RUBY
      # frozen_string_literal: true

      # Whodunit configuration
      # This file was generated by `whodunit install` command.
      # Uncomment and modify the options you want to customize.

      # Whodunit.configure do |config|
      #   # User model configuration
      #   # Specify which model represents users in your application
      #   config.user_class = 'Account'             # Default: 'User'
      #                                             # Use 'Account', 'Admin', etc. if your user model has a different name
      #
      #   # Column name configuration
      #   # Customize the names of the tracking columns in your database
      #   config.creator_column = :created_by_id    # Default: :creator_id
      #                                             # Column that stores who created the record
      #   config.updater_column = :updated_by_id    # Default: :updater_id
      #                                             # Column that stores who last updated the record
      #   config.deleter_column = :deleted_by_id    # Default: :deleter_id
      #                                             # Column that stores who deleted the record (soft-delete only)
      #
      #   # Soft-delete integration
      #   # Enable tracking of who deleted records when using soft-delete gems
      #   config.soft_delete_column = :discarded_at # Default: nil (disabled)
      #                                             # Set to :deleted_at for Paranoia gem
      #                                             # Set to :discarded_at for Discard gem
      #                                             # Set to your custom soft-delete column name
      #                                             # Set to nil to disable soft-delete tracking
      #
      #   # Migration auto-injection
      #   # Control whether whodunit stamps are automatically added to new migrations
      #   config.auto_inject_whodunit_stamps = false # Default: true
      #                                               # When true, automatically adds t.whodunit_stamps to create_table migrations
      #                                               # When false, you must manually add t.whodunit_stamps to your migrations
      #
      #   # Column data type configuration
      #   # Configure what data types to use for the tracking columns
      #   config.column_data_type = :integer       # Default: :bigint
      #                                            # Global default for all stamp columns
      #                                            # Common options: :bigint, :integer, :string, :uuid
      #
      #   # Individual column type overrides
      #   # Override the data type for specific columns (takes precedence over column_data_type)
      #   config.creator_column_type = :string     # Default: nil (uses column_data_type)
      #                                            # Useful if your user IDs are strings or UUIDs
      #   config.updater_column_type = :uuid       # Default: nil (uses column_data_type)
      #                                            # Set to match your user model's primary key type
      #   config.deleter_column_type = :integer    # Default: nil (uses column_data_type)
      #                                            # Only used when soft_delete_column is configured
      # end
    RUBY

    def self.install_initializer
      config_dir = "config/initializers"
      config_file = File.join(config_dir, "whodunit.rb")

      validate_rails_application!
      ensure_config_directory_exists!(config_dir)
      handle_existing_file!(config_file)
      create_initializer_file!(config_file)
      ApplicationRecordIntegration.handle_application_record_integration!
      show_success_message(config_file)
    end

    private_class_method def self.validate_rails_application!
      return if File.exist?("config/application.rb")

      puts "❌ Error: This doesn't appear to be a Rails application."
      puts "   Make sure you're in the root directory of your Rails app."
      exit 1
    end

    private_class_method def self.ensure_config_directory_exists!(config_dir)
      return if Dir.exist?(config_dir)

      puts "📁 Creating #{config_dir} directory..."
      FileUtils.mkdir_p(config_dir)
    end

    private_class_method def self.handle_existing_file!(config_file)
      return unless File.exist?(config_file)

      puts "⚠️  #{config_file} already exists!"
      print "   Do you want to overwrite it? (y/N): "
      response = $stdin.gets.chomp.downcase
      return if %w[y yes].include?(response)

      puts "   Cancelled."
      exit 0
    end

    private_class_method def self.create_initializer_file!(config_file)
      File.write(config_file, INITIALIZER_CONTENT)
      puts "✅ Generated #{config_file}"
    end

    private_class_method def self.show_success_message(config_file)
      puts ""
      puts "📝 Next steps:"
      puts "   1. Edit #{config_file} to customize your configuration"
      puts "   2. Uncomment the options you want to change"
      puts "   3. Add stamp columns to your models with migrations:"
      puts "      rails generate migration AddStampsToUsers"
      puts "      # Then add: add_whodunit_stamps :users"
      puts "   4. Restart your Rails server to apply changes"
      puts ""
      puts "📖 For more information, see: https://github.com/kanutocd/whodunit?tab=readme-ov-file#configuration"
    end

    def self.help_message
      <<~HELP
        Whodunit - Lightweight creator/updater/deleter tracking for ActiveRecord

        Usage:
          whodunit install    Generate config/initializers/whodunit.rb
          whodunit help       Show this help message

        Examples:
          whodunit install    # Creates config/initializers/whodunit.rb with sample configuration

        For more information, visit: https://github.com/kanutocd/whodunit
      HELP
    end
  end
end
