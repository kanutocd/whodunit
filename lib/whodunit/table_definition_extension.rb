# frozen_string_literal: true

module Whodunit
  # Extension for ActiveRecord::ConnectionAdapters::TableDefinition to automatically
  # inject whodunit_stamps when creating tables.
  #
  # This module monkey-patches the TableDefinition's column creation methods to
  # automatically add whodunit stamp columns when auto-injection is enabled.
  #
  # @example Enabling auto-injection
  #   Whodunit.configure do |config|
  #     config.auto_inject_whodunit_stamps = true
  #   end
  #
  #   # Now this migration will automatically include whodunit stamps:
  #   class CreatePosts < ActiveRecord::Migration[8.0]
  #     def change
  #       create_table :posts do |t|
  #         t.string :title
  #         t.text :body
  #         t.timestamps
  #         # t.whodunit_stamps automatically added at the end!
  #       end
  #     end
  #   end
  #
  # @since 0.1.0
  module TableDefinitionExtension
    extend ActiveSupport::Concern

    def _whodunit_stamps_added
      @_whodunit_stamps_added
    end

    def _whodunit_stamps_added=(value)
      @_whodunit_stamps_added = value
    end

    # Override timestamps to trigger automatic whodunit_stamps injection
    def timestamps(**options)
      options = options.dup
      skip = options.delete(:skip_whodunit_stamps)
      result = super

      if Whodunit.auto_inject_whodunit_stamps && !_whodunit_stamps_added && !skip
        whodunit_stamps(include_deleter: :auto)
      end

      result
    end

    # assign true tp the tracker `@_whodunit_stamps_added` before the
    # reuse/call of the `whodunit_stamps` flow from the Whodunit::MigrationHelpers module (see railtie.rb)
    #
    def whodunit_stamps(include_deleter: :auto, creator_type: nil, updater_type: nil, deleter_type: nil)
      self._whodunit_stamps_added = true
      self.class.whodunit_stamps(self, include_deleter:, creator_type:, updater_type:, deleter_type:)
    end
  end
end
