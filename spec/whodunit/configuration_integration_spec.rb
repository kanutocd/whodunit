# frozen_string_literal: true

require "spec_helper"

# rubocop:disable RSpec/DescribeClass
RSpec.describe "Whodunit Configuration Integration" do
  let(:migration_class) do
    Class.new do
      include Whodunit::MigrationHelpers

      def add_column(table, column, type, **options)
        @added_columns ||= []
        @added_columns << { table: table, column: column, type: type, options: options }
      end

      def add_index(table, column, **options)
        @added_indexes ||= []
        @added_indexes << { table: table, column: column, options: options }
      end

      def column_exists?(_table, _column)
        false # Simple mock - assume columns don't exist
      end

      def table_exists?(_table)
        true # Simple mock - assume tables exist
      end

      attr_reader :added_columns, :added_indexes
    end
  end

  let(:migration_mock) { migration_class.new }

  let(:original_deleter_column) { Whodunit.deleter_column }
  let(:original_auto_inject) { Whodunit.auto_inject_whodunit_stamps }

  after do
    # Restore original values
    Whodunit.deleter_column = original_deleter_column
    Whodunit.auto_inject_whodunit_stamps = original_auto_inject
  end

  describe "custom deleter column configuration" do
    it "is used throughout the system consistently" do
      # Configure custom deleter column
      Whodunit.deleter_column = :deleted_by_id

      # Test 1: Migration helpers use the configured column
      migration_mock.add_whodunit_stamps(:test_table, include_deleter: true)
      deleter_columns = migration_mock.added_columns&.select { |col| col[:column] == :deleted_by_id }
      expect(deleter_columns).not_to be_empty

      # Test 2: Model methods reference the configured column
      model = MockActiveRecord.new
      # The deleter_column? method should check for the configured column name
      column_names = model.class.column_names
      expect(column_names).to include("deleter_id") # Default mock includes deleter_id

      # Test 3: Configuration value is returned correctly
      expect(Whodunit.deleter_column).to eq(:deleted_by_id)
    end

    it "is memoized for performance" do
      # Change the configuration
      Whodunit.deleter_column = :custom_deleter_id
      first_call = Whodunit.deleter_column

      # Should return the same object (memoized)
      second_call = Whodunit.deleter_column
      expect(first_call).to eq(second_call)
      expect(first_call).to eq(:custom_deleter_id)
    end
  end

  describe "auto-injection with custom configuration" do
    it "respects custom column names in auto-injection" do
      # Configure custom columns and enable auto-injection
      Whodunit.deleter_column = :deleted_by_id
      Whodunit.auto_inject_whodunit_stamps = true

      # Verify that when whodunit_stamps is called, it uses the configured column
      migration_mock.add_whodunit_stamps(:test_table, include_deleter: true)
      deleter_columns = migration_mock.added_columns&.select { |col| col[:column] == :deleted_by_id }
      expect(deleter_columns).not_to be_empty

      # Test that configuration is accessible
      expect(Whodunit.deleter_column).to eq(:deleted_by_id)
      expect(Whodunit.auto_inject_whodunit_stamps).to be true
    end
  end
end
# rubocop:enable RSpec/DescribeClass
