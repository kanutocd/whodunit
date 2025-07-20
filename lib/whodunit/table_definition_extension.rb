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

    included do
      # Track whether whodunit_stamps have been automatically added
      attr_accessor :_whodunit_stamps_added
    end

    # Override timestamps to trigger automatic whodunit_stamps injection
    def timestamps(**options)
      result = super

      # Auto-inject whodunit_stamps after timestamps if enabled and not already added
      if Whodunit.auto_inject_whodunit_stamps &&
         !@_whodunit_stamps_added &&
         !options[:skip_whodunit_stamps]
        whodunit_stamps(include_deleter: :auto)
        @_whodunit_stamps_added = true
      end

      result
    end

    # Also override whodunit_stamps to track that they've been added
    def whodunit_stamps(**options)
      @_whodunit_stamps_added = true
      super
    end
  end
end
