# frozen_string_literal: true

module Whodunit
  # Main concern for adding creator/updater/deleter tracking to ActiveRecord models.
  #
  # This module provides automatic tracking of who created, updated, and deleted records.
  # It intelligently sets up callbacks and associations based on available columns and
  # soft-delete detection.
  #
  # @example Basic usage
  #   class Post < ApplicationRecord
  #     include Whodunit::Stampable
  #   end
  #
  #   # Requires creator_id and/or updater_id columns
  #   # Automatically adds deleter_id tracking if soft-delete is detected
  #
  # @example Migration
  #   class CreatePosts < ActiveRecord::Migration[7.0]
  #     def change
  #       create_table :posts do |t|
  #         t.string :title
  #         t.text :body
  #         t.whodunit_stamps  # Adds creator_id, updater_id columns
  #         t.timestamps
  #       end
  #     end
  #   end
  #
  # @example Manual deleter tracking
  #   class Post < ApplicationRecord
  #     include Whodunit::Stampable
  #
  #     # Force enable deleter tracking even without soft-delete
  #     enable_whodunit_deleter!
  #   end
  #
  # @since 0.1.0
  # rubocop:disable Metrics/ModuleLength
  module Stampable
    extend ActiveSupport::Concern

    included do
      # Set up callbacks - the if conditions will check per-model settings at runtime
      before_create :set_whodunit_creator, if: :creator_column?
      before_update :set_whodunit_updater, if: :updater_column?

      # Add deleter tracking for both hard and soft deletes
      # The if conditions will check per-model settings at runtime
      before_destroy :set_whodunit_deleter, if: :deleter_column?
      before_update :set_whodunit_deleter, if: :being_soft_deleted?

      # Set up associations - call on the class
      setup_whodunit_associations

      # Register this model for reverse association setup
      # This happens immediately, but the check for enabled status is done in register_model
      Whodunit.register_model(self)
    end

    class_methods do # rubocop:disable Metrics/BlockLength
      # Per-model configuration storage
      attr_accessor :whodunit_config_overrides

      # Configure per-model settings
      def whodunit_config
        @whodunit_config_overrides ||= {}
        yield @whodunit_config_overrides if block_given?
        @whodunit_config_overrides
      end

      def soft_delete_enabled?
        @soft_delete_enabled ||= model_soft_delete_enabled?
      end

      def enable_whodunit_deleter!
        before_destroy :set_whodunit_deleter, if: :deleter_column?
        before_update :set_whodunit_deleter, if: :being_soft_deleted?
        setup_deleter_association
        @soft_delete_enabled = true
      end

      def disable_whodunit_deleter!
        skip_callback :destroy, :before, :set_whodunit_deleter
        skip_callback :update, :before, :set_whodunit_deleter
        @soft_delete_enabled = false
      end

      # Disable reverse association setup for this model
      # Call this method in the model class to prevent automatic reverse associations
      # @example
      #   class Post < ApplicationRecord
      #     include Whodunit::Stampable
      #     disable_whodunit_reverse_associations!
      #   end
      def disable_whodunit_reverse_associations!
        @whodunit_reverse_associations_disabled = true
        # Remove from registered models if already registered
        Whodunit.registered_models.delete(self)
      end

      # Check if reverse associations are enabled for this model
      # @return [Boolean] true if reverse associations should be set up
      def whodunit_reverse_associations_enabled?
        !@whodunit_reverse_associations_disabled
      end

      # Manually set up reverse associations for this model
      # Can be called if reverse associations were disabled but you want to set them up later
      def setup_whodunit_reverse_associations!
        Whodunit.setup_reverse_associations_for_model(self) if whodunit_reverse_associations_enabled?
      end

      # Get effective configuration value (model override or global default)
      def whodunit_setting(key)
        return @whodunit_config_overrides[key] if @whodunit_config_overrides&.key?(key)

        Whodunit.public_send(key)
      end

      # Check if creator column is enabled for this model
      def model_creator_enabled?
        creator_column = whodunit_setting(:creator_column)
        !creator_column.nil?
      end

      # Check if updater column is enabled for this model
      def model_updater_enabled?
        updater_column = whodunit_setting(:updater_column)
        !updater_column.nil?
      end

      # Check if deleter column is enabled for this model
      def model_deleter_enabled?
        deleter_column = whodunit_setting(:deleter_column)
        !deleter_column.nil?
      end

      # Check if soft delete is enabled for this model
      def model_soft_delete_enabled?
        soft_delete_column = whodunit_setting(:soft_delete_column)
        !soft_delete_column.nil?
      end

      private

      def setup_whodunit_associations
        setup_creator_association if creator_column_exists? && model_creator_enabled?
        setup_updater_association if updater_column_exists? && model_updater_enabled?
        setup_deleter_association if deleter_column_exists? && model_deleter_enabled? && soft_delete_enabled?
      end

      def creator_column_exists?
        model_creator_enabled? && column_names.include?(whodunit_setting(:creator_column).to_s)
      end

      def updater_column_exists?
        model_updater_enabled? && column_names.include?(whodunit_setting(:updater_column).to_s)
      end

      def deleter_column_exists?
        model_deleter_enabled? && column_names.include?(whodunit_setting(:deleter_column).to_s)
      end

      def setup_creator_association
        belongs_to :creator,
                   class_name: whodunit_setting(:user_class).to_s,
                   foreign_key: whodunit_setting(:creator_column),
                   optional: true
      end

      def setup_updater_association
        belongs_to :updater,
                   class_name: whodunit_setting(:user_class).to_s,
                   foreign_key: whodunit_setting(:updater_column),
                   optional: true
      end

      def setup_deleter_association
        belongs_to :deleter,
                   class_name: whodunit_setting(:user_class).to_s,
                   foreign_key: whodunit_setting(:deleter_column),
                   optional: true
      end
    end

    # @!group Callback Methods

    # Set the creator ID when a record is created.
    #
    # This method is automatically called before_create if the model has a creator column.
    # It sets the creator_id to the current user from Whodunit::Current.
    #
    # @return [void]
    # @api private
    def set_whodunit_creator
      return unless Whodunit::Current.user_id

      self[self.class.whodunit_setting(:creator_column)] = Whodunit::Current.user_id
    end

    # Set the updater ID when a record is updated.
    #
    # This method is automatically called before_update if the model has an updater column.
    # It sets the updater_id to the current user from Whodunit::Current.
    # Does not run on new records (creation) or during soft-delete operations.
    #
    # @return [void]
    # @api private
    def set_whodunit_updater
      return unless Whodunit::Current.user_id

      return if new_record? # Don't set updater on creation

      return if being_soft_deleted? # Don't set updater during soft-delete

      self[self.class.whodunit_setting(:updater_column)] = Whodunit::Current.user_id
    end

    # Set the deleter ID when a record is destroyed or soft-deleted.
    #
    # This method is automatically called in two scenarios:
    # 1. before_destroy for hard deletes (if deleter column exists)
    # 2. before_update for soft-deletes (when being_soft_deleted? returns true)
    #
    # It sets the deleter_id to the current user from Whodunit::Current.
    #
    # @return [void]
    # @api private
    def set_whodunit_deleter
      return unless Whodunit::Current.user_id

      self[self.class.whodunit_setting(:deleter_column)] = Whodunit::Current.user_id
    end

    # @!group Column Presence Checks

    # Check if the model has a creator column and it's enabled.
    #
    # @return [Boolean] true if the creator column exists and is enabled
    # @api private
    def creator_column?
      return false unless self.class.model_creator_enabled?

      column_name = self.class.whodunit_setting(:creator_column).to_s
      self.class.column_names.include?(column_name)
    end

    # Check if the model has an updater column and it's enabled.
    #
    # @return [Boolean] true if the updater column exists and is enabled
    # @api private
    def updater_column?
      return false unless self.class.model_updater_enabled?

      column_name = self.class.whodunit_setting(:updater_column).to_s
      self.class.column_names.include?(column_name)
    end

    # Check if the model has a deleter column and it's enabled.
    #
    # @return [Boolean] true if the deleter column exists and is enabled
    # @api private
    def deleter_column?
      return false unless self.class.model_deleter_enabled?

      column_name = self.class.whodunit_setting(:deleter_column).to_s
      self.class.column_names.include?(column_name)
    end

    # Check if the current update operation is a soft-delete.
    #
    # Uses ActiveRecord's dirty tracking to detect if any soft-delete columns
    # are being changed from nil to a timestamp, which indicates a soft-delete operation.
    #
    # @return [Boolean] true if this update is setting a soft-delete timestamp
    # @api private
    def being_soft_deleted?
      return false unless deleter_column?
      return false unless Whodunit::Current.user_id

      soft_delete_column = self.class.whodunit_setting(:soft_delete_column)
      return false unless soft_delete_column

      # Simple: just check the configured soft-delete column
      column_name = soft_delete_column.to_s
      attribute_changed?(column_name) &&
        attribute_was(column_name).nil? &&
        !send(column_name).nil?
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
