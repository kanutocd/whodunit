# frozen_string_literal: true

require "active_support/all"
require_relative "whodunit/version"
require_relative "whodunit/current"
require_relative "whodunit/stampable"
require_relative "whodunit/migration_helpers"
require_relative "whodunit/controller_methods"
require_relative "whodunit/table_definition_extension"
require_relative "whodunit/railtie"

# Lightweight creator/updater/deleter tracking for ActiveRecord models.
#
# Whodunit provides simple auditing by tracking who created, updated, and deleted
# ActiveRecord models. It features smart soft-delete detection and zero performance overhead.
#
# @example Basic usage
#   class Post < ApplicationRecord
#     include Whodunit::Stampable
#   end
#
#   # In controller
#   Whodunit::Current.user = current_user
#   post = Post.create(title: "Hello")
#   post.creator_id # => current_user.id
#
# @example Configuration
#   Whodunit.configure do |config|
#     config.user_class = "Account"
#     config.creator_column = :created_by_id
#     config.column_data_type = :integer
#   end
#
# @author Ken C. Demanawa
# @since 0.1.0
module Whodunit
  # Base error class for all Whodunit exceptions
  class Error < StandardError; end

  # @!group Configuration

  # The class name of the user model (default: "User")
  # @return [String] the user class name
  mattr_accessor :user_class, default: "User"

  # The column name for tracking who created the record (default: :creator_id)
  # @return [Symbol] the creator column name
  mattr_accessor :creator_column, default: :creator_id

  # The column name for tracking who updated the record (default: :updater_id)
  # @return [Symbol] the updater column name
  mattr_accessor :updater_column, default: :updater_id

  # The column name for tracking who deleted the record (default: :deleter_id)
  # @return [Symbol] the deleter column name
  mattr_accessor :deleter_column, default: :deleter_id

  # The column name used for soft-delete timestamps (default: nil)
  # Set to a column name to enable soft-delete support (e.g., :deleted_at, :discarded_at)
  # Set to nil to disable soft-delete support entirely
  # @return [Symbol, nil] the soft-delete column name
  mattr_accessor :soft_delete_column, default: nil

  # Whether to automatically add whodunit_stamps to create_table migrations (default: true)
  # @return [Boolean] auto-injection setting
  mattr_accessor :auto_inject_whodunit_stamps, default: true

  # @!group Data Type Configuration

  # The default data type for stamp columns (default: :bigint)
  # @return [Symbol] the default column data type
  mattr_accessor :column_data_type, default: :bigint

  # Specific data type for creator column (overrides column_data_type if set)
  # @return [Symbol, nil] the creator column data type
  mattr_accessor :creator_column_type, default: nil

  # Specific data type for updater column (overrides column_data_type if set)
  # @return [Symbol, nil] the updater column data type
  mattr_accessor :updater_column_type, default: nil

  # Specific data type for deleter column (overrides column_data_type if set)
  # @return [Symbol, nil] the deleter column data type
  mattr_accessor :deleter_column_type, default: nil

  # Configure Whodunit settings
  #
  # @example
  #   Whodunit.configure do |config|
  #     config.user_class = "Account"
  #     config.creator_column = :created_by_id
  #     config.column_data_type = :integer
  #   end
  #
  # @yield [self] configuration block
  # @return [void]
  # @raise [Whodunit::Error] if both creator_column and updater_column are set to nil
  def self.configure
    yield self
    validate_column_configuration!
  end

  # Get the user class name as a string
  #
  # @return [String] the user class name
  def self.user_class_name
    user_class.to_s
  end

  # @!group Data Type Helpers

  # Get the data type for the creator column
  # @return [Symbol] the creator column data type
  def self.creator_data_type
    creator_column_type || column_data_type
  end

  # Get the data type for the updater column
  # @return [Symbol] the updater column data type
  def self.updater_data_type
    updater_column_type || column_data_type
  end

  # Get the data type for the deleter column
  # @return [Symbol] the deleter column data type
  def self.deleter_data_type
    deleter_column_type || column_data_type
  end

  # Check if soft-delete is enabled
  # @return [Boolean] true if soft-delete is configured (soft_delete_column is not nil)
  def self.soft_delete_enabled?
    !soft_delete_column.nil?
  end

  # Check if creator column is enabled
  # @return [Boolean] true if creator_column is not nil
  def self.creator_enabled?
    !creator_column.nil?
  end

  # Check if updater column is enabled
  # @return [Boolean] true if updater_column is not nil
  def self.updater_enabled?
    !updater_column.nil?
  end

  # Check if deleter column is enabled
  # @return [Boolean] true if deleter_column is not nil
  def self.deleter_enabled?
    !deleter_column.nil?
  end

  # Validate that column configuration is valid
  # @raise [Whodunit::Error] if both creator_column and updater_column are nil
  def self.validate_column_configuration!
    return if creator_enabled? || updater_enabled?

    raise Whodunit::Error,
          "At least one of creator_column or updater_column must be configured (not nil). " \
          "Setting both to nil would disable all stamping functionality."
  end
end
