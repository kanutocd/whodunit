# frozen_string_literal: true

module Whodunit
  module Stampable
    extend ActiveSupport::Concern

    included do
      # Set up callbacks
      before_create :set_whodunit_creator, if: :has_creator_column?
      before_update :set_whodunit_updater, if: :has_updater_column?

      # Only add destroy callback if soft-delete is detected
      if Whodunit.auto_detect_soft_delete &&
         Whodunit::SoftDeleteDetector.enabled_for?(self)
        before_destroy :set_whodunit_deleter, if: :has_deleter_column?
      end

      # Set up associations - call on the class
      setup_whodunit_associations
    end

    class_methods do
      def soft_delete_enabled?
        @soft_delete_enabled ||= Whodunit::SoftDeleteDetector.enabled_for?(self)
      end

      def enable_whodunit_deleter!
        before_destroy :set_whodunit_deleter, if: :has_deleter_column?
        setup_deleter_association
        @soft_delete_enabled = true
      end

      def disable_whodunit_deleter!
        skip_callback :destroy, :before, :set_whodunit_deleter
        @soft_delete_enabled = false
      end

      private

      def setup_whodunit_associations
        setup_creator_association if column_names.include?(Whodunit.creator_column.to_s)
        setup_updater_association if column_names.include?(Whodunit.updater_column.to_s)
        setup_deleter_association if column_names.include?(Whodunit.deleter_column.to_s) && soft_delete_enabled?
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

    def set_whodunit_creator
      return unless Whodunit::Current.user_id

      self[Whodunit.creator_column] = Whodunit::Current.user_id
    end

    def set_whodunit_updater
      return unless Whodunit::Current.user_id
      return if new_record? # Don't set updater on creation

      self[Whodunit.updater_column] = Whodunit::Current.user_id
    end

    def set_whodunit_deleter
      return unless Whodunit::Current.user_id

      self[Whodunit.deleter_column] = Whodunit::Current.user_id
    end

    def has_creator_column?
      self.class.column_names.include?(Whodunit.creator_column.to_s)
    end

    def has_updater_column?
      self.class.column_names.include?(Whodunit.updater_column.to_s)
    end

    def has_deleter_column?
      self.class.column_names.include?(Whodunit.deleter_column.to_s)
    end
  end
end
