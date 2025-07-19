# frozen_string_literal: true

module Whodunit
  # Smart detection of soft-delete implementations.
  #
  # This class provides multi-layered detection for various soft-delete implementations
  # including popular gems like Discard and Paranoia, as well as custom implementations.
  #
  # @example Check if a model has soft-delete enabled
  #   class Post < ApplicationRecord
  #     # has deleted_at column
  #   end
  #
  #   Whodunit::SoftDeleteDetector.enabled_for?(Post)  # => true
  #
  # @example With Discard gem
  #   class Post < ApplicationRecord
  #     include Discard::Model
  #   end
  #
  #   Whodunit::SoftDeleteDetector.enabled_for?(Post)  # => true
  #
  # @since 0.1.0
  class SoftDeleteDetector
    # Main detection method that checks if soft-delete is enabled for a model.
    #
    # Uses multiple detection strategies:
    # 1. Gem-based detection (Discard, Paranoia, etc.)
    # 2. Column pattern detection (deleted_at, discarded_at, etc.)
    # 3. Method-based detection (respond_to? soft-delete methods)
    #
    # @param model [Class] the ActiveRecord model class to check
    # @return [Boolean] true if soft-delete is detected, false otherwise
    # @example
    #   Whodunit::SoftDeleteDetector.enabled_for?(Post)  # => true
    #   Whodunit::SoftDeleteDetector.enabled_for?(User)  # => false
    def self.enabled_for?(model)
      return false unless model.respond_to?(:columns)

      gem_based_detection?(model) ||
        column_pattern_detection(model) ||
        method_based_detection(model)
    end

    # Detect popular soft-delete gems.
    #
    # Detects the following gems:
    # - Discard (checks for Discard module inclusion)
    # - Paranoia (checks for paranoid? method and Paranoid ancestors)
    # - ActsAsParanoid (checks for acts_as_paranoid method)
    #
    # @param model [Class] the ActiveRecord model class to check
    # @return [Boolean] true if a gem-based soft-delete is detected
    # @api private
    def self.gem_based_detection?(model)
      # Discard gem
      return true if model.included_modules.any? { |mod| mod.to_s.include?("Discard") }

      # Paranoia gem
      return true if model.respond_to?(:paranoid?) ||
                     model.respond_to?(:acts_as_paranoid) ||
                     model.ancestors.any? { |a| a.to_s.include?("Paranoid") }

      # ActsAsParanoid (older version)
      return true if model.respond_to?(:acts_as_paranoid)

      false
    end

    # Detect soft-delete by column patterns.
    #
    # Looks for common soft-delete column names:
    # - deleted_at, destroyed_at, discarded_at, archived_at
    # - soft_deleted_at, soft_destroyed_at, removed_at
    #
    # Only considers timestamp columns (datetime, timestamp, date).
    #
    # @param model [Class] the ActiveRecord model class to check
    # @return [Boolean] true if soft-delete columns are found
    # @api private
    def self.column_pattern_detection(model)
      soft_delete_columns = %w[
        deleted_at destroyed_at discarded_at archived_at
        soft_deleted_at soft_destroyed_at removed_at
      ]

      model.columns.any? do |column|
        soft_delete_columns.include?(column.name) &&
          timestamp_column?(column)
      end
    end

    # Detect soft-delete by method presence.
    #
    # Checks if the model responds to common soft-delete method names.
    # This catches custom implementations that follow standard naming conventions.
    #
    # @param model [Class] the ActiveRecord model class to check
    # @return [Boolean] true if soft-delete methods are found
    # @api private
    def self.method_based_detection(model)
      soft_delete_methods = %w[
        deleted_at destroyed_at discarded_at archived_at
        soft_deleted_at soft_destroyed_at removed_at
      ]

      soft_delete_methods.any? { |method| model.respond_to?(method) }
    end

    # Check if a column is a timestamp type.
    #
    # @param column [Object] the column object (responds to #type)
    # @return [Boolean] true if the column is a timestamp type
    # @api private
    def self.timestamp_column?(column)
      %i[datetime timestamp date].include?(column.type)
    end
  end
end
