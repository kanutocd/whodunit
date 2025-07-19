# frozen_string_literal: true

module Whodunit
  # Database migration helpers for adding whodunit stamp columns.
  #
  # This module provides convenient methods for adding creator/updater/deleter
  # tracking columns to database tables. It intelligently detects soft-delete
  # implementations and adds appropriate indexes for performance.
  #
  # @example Add stamps to existing table
  #   class AddWhodunitStampsToPosts < ActiveRecord::Migration[7.0]
  #     def change
  #       add_whodunit_stamps :posts
  #       # Adds creator_id, updater_id columns
  #       # Adds deleter_id if soft-delete detected
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
  # @example Custom data types
  #   add_whodunit_stamps :posts,
  #     creator_type: :string,
  #     updater_type: :uuid,
  #     include_deleter: true
  #
  # @since 0.1.0
  module MigrationHelpers
    # Add creator/updater stamp columns to an existing table.
    #
    # This method adds the configured creator and updater columns to an existing table.
    # It optionally adds a deleter column based on soft-delete detection or explicit configuration.
    # Indexes are automatically added for performance.
    #
    # @param table_name [Symbol] the table to add stamps to
    # @param include_deleter [Symbol, Boolean] :auto to auto-detect soft-delete,
    #   true to force inclusion, false to exclude
    # @param creator_type [Symbol, nil] data type for creator column (defaults to configured type)
    # @param updater_type [Symbol, nil] data type for updater column (defaults to configured type)
    # @param deleter_type [Symbol, nil] data type for deleter column (defaults to configured type)
    # @return [void]
    # @example Basic usage
    #   add_whodunit_stamps :posts
    # @example With custom types
    #   add_whodunit_stamps :posts, creator_type: :string, updater_type: :uuid
    # @example Force deleter column
    #   add_whodunit_stamps :posts, include_deleter: true
    def add_whodunit_stamps(table_name, include_deleter: :auto, creator_type: nil, updater_type: nil, deleter_type: nil)
      add_column table_name, Whodunit.creator_column, creator_type || Whodunit.creator_data_type, null: true
      add_column table_name, Whodunit.updater_column, updater_type || Whodunit.updater_data_type, null: true

      if should_include_deleter?(table_name, include_deleter)
        add_column table_name, Whodunit.deleter_column, deleter_type || Whodunit.deleter_data_type, null: true
      end

      add_whodunit_indexes(table_name, include_deleter)
    end

    # Remove stamp columns from an existing table.
    #
    # This method removes the configured creator, updater, and optionally deleter
    # columns from an existing table. Only removes columns that actually exist.
    #
    # @param table_name [Symbol] the table to remove stamps from
    # @param include_deleter [Symbol, Boolean] :auto to auto-detect soft-delete,
    #   true to force removal, false to exclude
    # @param _options [Hash] additional options (reserved for future use)
    # @return [void]
    # @example Basic usage
    #   remove_whodunit_stamps :posts
    # @example Force deleter removal
    #   remove_whodunit_stamps :posts, include_deleter: true
    def remove_whodunit_stamps(table_name, include_deleter: :auto, **_options)
      remove_column table_name, Whodunit.creator_column if column_exists?(table_name, Whodunit.creator_column)
      remove_column table_name, Whodunit.updater_column if column_exists?(table_name, Whodunit.updater_column)

      if should_include_deleter?(table_name, include_deleter) &&
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
    # @param table_def [ActiveRecord::ConnectionAdapters::TableDefinition, nil]
    #   the table definition (when used in create_table block) or nil
    # @param include_deleter [Symbol, Boolean] :auto to auto-detect soft-delete,
    #   true to force inclusion, false to exclude
    # @param creator_type [Symbol, nil] data type for creator column (defaults to configured type)
    # @param updater_type [Symbol, nil] data type for updater column (defaults to configured type)
    # @param deleter_type [Symbol, nil] data type for deleter column (defaults to configured type)
    # @return [void]
    # @example In create_table block
    #   create_table :posts do |t|
    #     t.string :title
    #     t.whodunit_stamps
    #   end
    # @example Standalone (infers table from migration name)
    #   def change
    #     whodunit_stamps  # Adds to inferred table
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
      table_def.column Whodunit.creator_column, creator_type || Whodunit.creator_data_type, null: true
      table_def.column Whodunit.updater_column, updater_type || Whodunit.updater_data_type, null: true

      if should_include_deleter_for_new_table?(include_deleter)
        table_def.column Whodunit.deleter_column, deleter_type || Whodunit.deleter_data_type, null: true
      end

      add_whodunit_indexes_for_create_table(table_def, include_deleter)
    end

    # Determine if deleter column should be included
    def should_include_deleter?(table_name, include_deleter)
      case include_deleter
      when :auto
        soft_delete_detected_for_table?(table_name)
      when true
        true
      else
        false
      end
    end

    # For new tables, be more conservative with auto-detection
    def should_include_deleter_for_new_table?(include_deleter)
      case include_deleter
      when true
        true
      else
        false # Don't auto-add for new tables, let user be explicit
      end
    end

    # Detect soft-delete patterns in existing table
    def soft_delete_detected_for_table?(table_name)
      return false unless table_exists?(table_name)

      soft_delete_columns = %w[
        deleted_at destroyed_at discarded_at archived_at
        soft_deleted_at soft_destroyed_at removed_at
      ]

      soft_delete_columns.any? { |col| column_exists?(table_name, col) || column_exists?(table_name, col.to_sym) }
    end

    # Add indexes for performance
    def add_whodunit_indexes(table_name, include_deleter)
      add_index table_name, Whodunit.creator_column, name: "index_#{table_name}_on_creator"
      add_index table_name, Whodunit.updater_column, name: "index_#{table_name}_on_updater"

      return unless should_include_deleter?(table_name, include_deleter)

      add_index table_name, Whodunit.deleter_column, name: "index_#{table_name}_on_deleter"
    end

    # Add indexes within create_table block
    def add_whodunit_indexes_for_create_table(table_def, include_deleter)
      # Skip indexes for table definitions that don't support them
      return unless table_def.respond_to?(:index)

      table_name = table_def.respond_to?(:name) ? table_def.name : "table"
      table_def.index Whodunit.creator_column, name: "index_#{table_name}_on_creator"
      table_def.index Whodunit.updater_column, name: "index_#{table_name}_on_updater"

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
