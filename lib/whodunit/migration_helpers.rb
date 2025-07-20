# frozen_string_literal: true

module Whodunit
  # Database migration helpers for adding whodunit stamp columns.
  #
  # This module provides convenient methods for adding creator/updater/deleter
  # tracking columns to database tables based on configuration. Uses the configured
  # column names and data types, and adds appropriate indexes for performance.
  #
  # The helpers respect column enabling/disabling configuration:
  # - Only adds columns that are enabled (not nil) in configuration
  # - Uses configured column names and data types
  # - Deleter column inclusion based on soft_delete_column configuration
  #
  # @example Add stamps to existing table
  #   class AddWhodunitStampsToPosts < ActiveRecord::Migration[7.0]
  #     def change
  #       add_whodunit_stamps :posts
  #       # Adds enabled columns: creator_id, updater_id
  #       # Adds deleter_id if soft_delete_column is configured
  #     end
  #   end
  #
  # @example Add stamps to new table
  #   class CreatePosts < ActiveRecord::Migration[7.0]
  #     def change
  #       create_table :posts do |t|
  #         t.string :title
  #         t.text :body
  #         t.whodunit_stamps
  #         t.timestamps
  #       end
  #     end
  #   end
  #
  # @example Custom data types and explicit deleter inclusion
  #   add_whodunit_stamps :posts,
  #     creator_type: :string,
  #     updater_type: :uuid,
  #     include_deleter: true
  #
  # @example With custom column configuration
  #   # In config/initializers/whodunit.rb:
  #   Whodunit.configure do |config|
  #     config.creator_column = :created_by_id
  #     config.deleter_column = nil  # Disable deleter column
  #     config.soft_delete_column = :archived_at
  #   end
  #
  #   # Migration will use custom column names and only add enabled columns
  #
  # @since 0.1.0
  module MigrationHelpers
    # Add creator/updater/deleter stamp columns to an existing table.
    #
    # This method adds the configured whodunit columns to an existing table based on
    # the current configuration. Only adds columns that are enabled (not nil).
    # The deleter column is included based on soft_delete_column configuration when
    # include_deleter is :auto, or explicitly when include_deleter is true.
    # Indexes are automatically added for performance.
    #
    # @param table_name [Symbol] the table to add stamps to
    # @param include_deleter [Symbol, Boolean] :auto to check soft_delete_column configuration,
    #   true to force inclusion, false to exclude
    # @param creator_type [Symbol, nil] data type for creator column (defaults to configured type)
    # @param updater_type [Symbol, nil] data type for updater column (defaults to configured type)
    # @param deleter_type [Symbol, nil] data type for deleter column (defaults to configured type)
    # @return [void]
    # @example Basic usage (uses configuration)
    #   add_whodunit_stamps :posts
    # @example With custom types
    #   add_whodunit_stamps :posts, creator_type: :string, updater_type: :uuid
    # @example Force deleter column inclusion
    #   add_whodunit_stamps :posts, include_deleter: true
    # @example Exclude deleter column
    #   add_whodunit_stamps :posts, include_deleter: false
    def add_whodunit_stamps(table_name, include_deleter: :auto, creator_type: nil, updater_type: nil, deleter_type: nil)
      if Whodunit.creator_enabled?
        add_column table_name, Whodunit.creator_column, creator_type || Whodunit.creator_data_type, null: true
      end

      if Whodunit.updater_enabled?
        add_column table_name, Whodunit.updater_column, updater_type || Whodunit.updater_data_type, null: true
      end

      if should_include_deleter?(include_deleter)
        add_column table_name, Whodunit.deleter_column, deleter_type || Whodunit.deleter_data_type, null: true
      end

      add_whodunit_indexes(table_name, include_deleter)
    end

    # Remove stamp columns from an existing table.
    #
    # This method removes the configured creator, updater, and optionally deleter
    # columns from an existing table. Only removes columns that are enabled in
    # configuration and actually exist in the database.
    #
    # @param table_name [Symbol] the table to remove stamps from
    # @param include_deleter [Symbol, Boolean] :auto to check soft_delete_column configuration,
    #   true to force removal, false to exclude
    # @param _options [Hash] additional options (reserved for future use)
    # @return [void]
    # @example Basic usage (uses configuration)
    #   remove_whodunit_stamps :posts
    # @example Force deleter removal
    #   remove_whodunit_stamps :posts, include_deleter: true
    # @example Exclude deleter removal
    #   remove_whodunit_stamps :posts, include_deleter: false
    def remove_whodunit_stamps(table_name, include_deleter: :auto, **_options)
      if Whodunit.creator_enabled? && column_exists?(table_name, Whodunit.creator_column)
        remove_column table_name, Whodunit.creator_column
      end

      if Whodunit.updater_enabled? && column_exists?(table_name, Whodunit.updater_column)
        remove_column table_name, Whodunit.updater_column
      end

      if should_include_deleter?(include_deleter) &&
         column_exists?(table_name, Whodunit.deleter_column)
        remove_column table_name, Whodunit.deleter_column
      end
    end

    # Add stamp columns to a table definition or existing table.
    #
    # This method can be used in two ways:
    # 1. Inside a create_table block (pass table definition as first argument)
    # 2. As a standalone method in migrations (attempts to infer table name)
    #
    # Only adds columns that are enabled in configuration. For new tables,
    # deleter column is only added when explicitly requested (include_deleter: true)
    # to be conservative.
    #
    # @param table_def [ActiveRecord::ConnectionAdapters::TableDefinition, nil]
    #   the table definition (when used in create_table block) or nil
    # @param include_deleter [Symbol, Boolean] :auto to check soft_delete_column configuration,
    #   true to force inclusion, false to exclude
    # @param creator_type [Symbol, nil] data type for creator column (defaults to configured type)
    # @param updater_type [Symbol, nil] data type for updater column (defaults to configured type)
    # @param deleter_type [Symbol, nil] data type for deleter column (defaults to configured type)
    # @return [void]
    # @example In create_table block (uses configuration)
    #   create_table :posts do |t|
    #     t.string :title
    #     t.whodunit_stamps
    #   end
    # @example Standalone (infers table from migration name)
    #   def change
    #     whodunit_stamps  # Adds to inferred table
    #   end
    # @example Force deleter column in new table
    #   create_table :posts do |t|
    #     t.whodunit_stamps include_deleter: true
    #   end
    def whodunit_stamps(table_def = nil, include_deleter: :auto, creator_type: nil, updater_type: nil,
                        deleter_type: nil)
      if table_def.nil?
        handle_migration_stamps(include_deleter, creator_type, updater_type, deleter_type)
      else
        handle_table_definition_stamps(table_def, include_deleter, creator_type, updater_type, deleter_type)
      end
    end

    private

    # Handle stamps when called as migration method
    def handle_migration_stamps(include_deleter, creator_type, updater_type, deleter_type)
      table_name = infer_table_name_from_migration
      return unless table_name

      add_whodunit_stamps(table_name, include_deleter: include_deleter, creator_type: creator_type,
                                      updater_type: updater_type, deleter_type: deleter_type)
    end

    # Handle stamps when called within create_table block
    def handle_table_definition_stamps(table_def, include_deleter, creator_type, updater_type, deleter_type)
      if Whodunit.creator_enabled?
        table_def.column Whodunit.creator_column, creator_type || Whodunit.creator_data_type, null: true
      end

      if Whodunit.updater_enabled?
        table_def.column Whodunit.updater_column, updater_type || Whodunit.updater_data_type, null: true
      end

      if should_include_deleter_for_new_table?(include_deleter)
        table_def.column Whodunit.deleter_column, deleter_type || Whodunit.deleter_data_type, null: true
      end

      add_whodunit_indexes_for_create_table(table_def, include_deleter)
    end

    # Determine if deleter column should be included based on configuration.
    # When :auto, checks if soft_delete_column is configured (not nil).
    # @param include_deleter [Symbol, Boolean] the inclusion preference
    # @return [Boolean] true if deleter column should be included
    def should_include_deleter?(include_deleter)
      include_deleter == :auto ? soft_delete_enabled? : include_deleter.eql?(true)
    end

    # For new tables, be more conservative - only include deleter when explicitly requested.
    # This prevents adding deleter columns to tables that may not need them.
    # @param include_deleter [Symbol, Boolean] the inclusion preference
    # @return [Boolean] true only when explicitly requested (true)
    def should_include_deleter_for_new_table?(include_deleter)
      include_deleter.eql?(true)
    end

    # Check if soft-delete is enabled based on configuration.
    # Uses the configured soft_delete_column - if it's set (not nil), soft delete is enabled.
    # @return [Boolean] true if soft_delete_column is configured
    def soft_delete_enabled?
      # Simple configuration-based check - trust the user's configuration
      Whodunit.soft_delete_enabled?
    end

    # Add indexes for performance
    def add_whodunit_indexes(table_name, include_deleter)
      add_index table_name, Whodunit.creator_column, name: "index_#{table_name}_on_creator" if Whodunit.creator_enabled?

      add_index table_name, Whodunit.updater_column, name: "index_#{table_name}_on_updater" if Whodunit.updater_enabled?

      return unless should_include_deleter?(include_deleter)

      add_index table_name, Whodunit.deleter_column, name: "index_#{table_name}_on_deleter"
    end

    # Add indexes within create_table block
    def add_whodunit_indexes_for_create_table(table_def, include_deleter)
      # Skip indexes for table definitions that don't support them
      return unless table_def.respond_to?(:index)

      table_name = table_def.respond_to?(:name) ? table_def.name : "table"

      table_def.index Whodunit.creator_column, name: "index_#{table_name}_on_creator" if Whodunit.creator_enabled?

      table_def.index Whodunit.updater_column, name: "index_#{table_name}_on_updater" if Whodunit.updater_enabled?

      return unless should_include_deleter_for_new_table?(include_deleter)

      table_def.index Whodunit.deleter_column, name: "index_#{table_name}_on_deleter"
    end

    # Attempt to infer table name from migration class name
    def infer_table_name_from_migration
      return nil unless respond_to?(:migration_name)

      # Extract table name from migration names like CreatePosts, AddStampsToPosts
      case migration_name
      when /^Create(\w+)$/
        table_name = ::Regexp.last_match(1)
        table_name.respond_to?(:underscore) ? table_name.underscore.pluralize : "#{table_name.downcase}s"
      when /^Add\w*To(\w+)$/
        table_name = ::Regexp.last_match(1)
        table_name.respond_to?(:underscore) ? table_name.underscore : table_name.downcase
      end
    end

    # Get migration name from class
    def migration_name
      self.class.name.demodulize
    end
  end
end

# Extend ActiveRecord::Migration when available
ActiveRecord::Migration.include(Whodunit::MigrationHelpers) if defined?(ActiveRecord::Migration)
