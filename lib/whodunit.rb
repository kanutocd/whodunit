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

  # @!group Reverse Association Configuration

  # Whether to automatically set up reverse associations on the user class (default: true)
  # When enabled, including Whodunit::Stampable in a model will automatically add
  # has_many associations to the user class (e.g., has_many :created_posts)
  # @return [Boolean] auto reverse association setting
  mattr_accessor :auto_setup_reverse_associations, default: true

  # Prefix for reverse association names (default: "")
  # Used to generate association names like "created_posts", "updated_comments"
  # @return [String] the prefix for reverse association names
  mattr_accessor :reverse_association_prefix, default: ""

  # Suffix for reverse association names (default: "")
  # Used to generate association names like "posts_created", "comments_updated"
  # @return [String] the suffix for reverse association names
  mattr_accessor :reverse_association_suffix, default: ""

  # @!group Model Registry

  # Registry to track models that include Whodunit::Stampable
  # This is used to set up reverse associations on the user class
  # @return [Array<Class>] array of model classes that include Stampable
  mattr_accessor :registered_models, default: []

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

  # @!group Model Registration & Reverse Associations

  # Register a model class that includes Whodunit::Stampable
  # This is called automatically when Stampable is included
  # @param [Class] model_class the model class to register
  # @return [void]
  def self.register_model(model_class)
    return unless auto_setup_reverse_associations
    return if registered_models.include?(model_class)
    return if model_class.respond_to?(:whodunit_reverse_associations_enabled?) &&
              !model_class.whodunit_reverse_associations_enabled?

    registered_models << model_class
    setup_reverse_associations_for_model(model_class)
  end

  # Set up reverse associations on the user class for a specific model
  # @param [Class] model_class the model class to set up reverse associations for
  # @return [void]
  def self.setup_reverse_associations_for_model(model_class)
    return unless auto_setup_reverse_associations

    user_class_instance = resolve_user_class
    return unless user_class_instance.respond_to?(:has_many)

    model_plural = model_class.name.underscore.pluralize

    setup_creator_reverse_association(user_class_instance, model_class, model_plural)
    setup_updater_reverse_association(user_class_instance, model_class, model_plural)
    setup_deleter_reverse_association(user_class_instance, model_class, model_plural)
  end

  # Set up all reverse associations for all registered models
  # This can be called manually if needed (e.g., after configuration changes)
  # @return [void]
  def self.setup_all_reverse_associations
    registered_models.each do |model_class|
      setup_reverse_associations_for_model(model_class)
    end
  end

  # Generate a reverse association name based on action and model name
  # @param [String] action the action (created, updated, deleted)
  # @param [String] model_plural the pluralized model name
  # @return [String] the generated association name
  def self.generate_reverse_association_name(action, model_plural)
    "#{reverse_association_prefix}#{action}_#{model_plural}#{reverse_association_suffix}"
  end

  # Resolve the user class constant
  # @return [Class, nil] the user class or nil if not found
  def self.resolve_user_class
    user_class.constantize
  rescue StandardError
    nil
  end

  # Set up creator reverse association
  # @param [Class] user_class_instance the user class
  # @param [Class] model_class the model class
  # @param [String] model_plural the pluralized model name
  # @return [void]
  def self.setup_creator_reverse_association(user_class_instance, model_class, model_plural)
    return unless model_class.respond_to?(:model_creator_enabled?) && model_class.model_creator_enabled?

    association_name = generate_reverse_association_name("created", model_plural)
    setup_user_reverse_association(user_class_instance, association_name, model_class, :creator_id)
  end

  # Set up updater reverse association
  # @param [Class] user_class_instance the user class
  # @param [Class] model_class the model class
  # @param [String] model_plural the pluralized model name
  # @return [void]
  def self.setup_updater_reverse_association(user_class_instance, model_class, model_plural)
    return unless model_class.respond_to?(:model_updater_enabled?) && model_class.model_updater_enabled?

    association_name = generate_reverse_association_name("updated", model_plural)
    setup_user_reverse_association(user_class_instance, association_name, model_class, :updater_id)
  end

  # Set up deleter reverse association
  # @param [Class] user_class_instance the user class
  # @param [Class] model_class the model class
  # @param [String] model_plural the pluralized model name
  # @return [void]
  def self.setup_deleter_reverse_association(user_class_instance, model_class, model_plural)
    return unless model_class.respond_to?(:model_deleter_enabled?) && model_class.model_deleter_enabled?
    return unless model_class.respond_to?(:soft_delete_enabled?) && model_class.soft_delete_enabled?

    association_name = generate_reverse_association_name("deleted", model_plural)
    setup_user_reverse_association(user_class_instance, association_name, model_class, :deleter_id)
  end

  # Set up a specific reverse association on the user class
  # @param [Class] user_class_instance the user class
  # @param [String] association_name the name of the association
  # @param [Class] model_class the model class
  # @param [Symbol] foreign_key_column the foreign key column name
  # @return [void]
  def self.setup_user_reverse_association(user_class_instance, association_name, model_class, foreign_key_column)
    actual_foreign_key = resolve_foreign_key(model_class, foreign_key_column)

    # Check if association already exists to avoid duplicates
    return if user_class_instance.reflect_on_association(association_name.to_sym)

    user_class_instance.has_many association_name.to_sym,
                                 class_name: model_class.name,
                                 foreign_key: actual_foreign_key,
                                 dependent: :nullify
  end

  # Resolve the actual foreign key column name from model configuration
  # @param [Class] model_class the model class
  # @param [Symbol] foreign_key_column the default foreign key column
  # @return [Symbol] the actual foreign key column name
  def self.resolve_foreign_key(model_class, foreign_key_column)
    return foreign_key_column unless model_class.respond_to?(:whodunit_setting)

    column_mapping = {
      creator_id: :creator_column,
      updater_id: :updater_column,
      deleter_id: :deleter_column
    }

    setting_key = column_mapping[foreign_key_column]
    setting_key ? (model_class.whodunit_setting(setting_key) || foreign_key_column) : foreign_key_column
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
