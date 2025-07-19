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
  module Stampable
    extend ActiveSupport::Concern

    included do
      # Set up callbacks
      before_create :set_whodunit_creator, if: :creator_column?
      before_update :set_whodunit_updater, if: :updater_column?

      # Only add destroy callback if soft-delete is detected
      if Whodunit.auto_detect_soft_delete &&
         Whodunit::SoftDeleteDetector.enabled_for?(self)
        before_destroy :set_whodunit_deleter, if: :deleter_column?
      end

      # Set up associations - call on the class
      setup_whodunit_associations
    end

    class_methods do # rubocop:disable Metrics/BlockLength
      def soft_delete_enabled?
        @soft_delete_enabled ||= Whodunit::SoftDeleteDetector.enabled_for?(self)
      end

      def enable_whodunit_deleter!
        before_destroy :set_whodunit_deleter, if: :deleter_column?
        setup_deleter_association
        @soft_delete_enabled = true
      end

      def disable_whodunit_deleter!
        skip_callback :destroy, :before, :set_whodunit_deleter
        @soft_delete_enabled = false
      end

      private

      def setup_whodunit_associations
        setup_creator_association if creator_column_exists?
        setup_updater_association if updater_column_exists?
        setup_deleter_association if deleter_column_exists? && soft_delete_enabled?
      end

      def creator_column_exists?
        column_names.include?(Whodunit.creator_column.to_s)
      end

      def updater_column_exists?
        column_names.include?(Whodunit.updater_column.to_s)
      end

      def deleter_column_exists?
        column_names.include?(Whodunit.deleter_column.to_s)
      end

      def setup_creator_association
        belongs_to :creator,
                   class_name: Whodunit.user_class_name,
                   foreign_key: Whodunit.creator_column,
                   optional: true
      end

      def setup_updater_association
        belongs_to :updater,
                   class_name: Whodunit.user_class_name,
                   foreign_key: Whodunit.updater_column,
                   optional: true
      end

      def setup_deleter_association
        belongs_to :deleter,
                   class_name: Whodunit.user_class_name,
                   foreign_key: Whodunit.deleter_column,
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

      self[Whodunit.creator_column] = Whodunit::Current.user_id
    end

    # Set the updater ID when a record is updated.
    #
    # This method is automatically called before_update if the model has an updater column.
    # It sets the updater_id to the current user from Whodunit::Current.
    # Does not run on new records (creation).
    #
    # @return [void]
    # @api private
    def set_whodunit_updater
      return unless Whodunit::Current.user_id
      return if new_record? # Don't set updater on creation

      self[Whodunit.updater_column] = Whodunit::Current.user_id
    end

    # Set the deleter ID when a record is destroyed.
    #
    # This method is automatically called before_destroy if the model has a deleter column
    # and soft-delete is enabled. It sets the deleter_id to the current user from Whodunit::Current.
    #
    # @return [void]
    # @api private
    def set_whodunit_deleter
      return unless Whodunit::Current.user_id

      self[Whodunit.deleter_column] = Whodunit::Current.user_id
    end

    # @!group Column Presence Checks

    # Check if the model has a creator column.
    #
    # @return [Boolean] true if the creator column exists
    # @api private
    def creator_column?
      self.class.column_names.include?(Whodunit.creator_column.to_s)
    end

    # Check if the model has an updater column.
    #
    # @return [Boolean] true if the updater column exists
    # @api private
    def updater_column?
      self.class.column_names.include?(Whodunit.updater_column.to_s)
    end

    # Check if the model has a deleter column.
    #
    # @return [Boolean] true if the deleter column exists
    # @api private
    def deleter_column?
      self.class.column_names.include?(Whodunit.deleter_column.to_s)
    end
  end
end
