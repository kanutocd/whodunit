# frozen_string_literal: true

require "spec_helper"

RSpec.describe Whodunit::MigrationHelpers do
  # Migration-level helper (add_column / remove_column)
  # This is a plain adapter layer;

  let(:migration_recorder) do
    Class.new do
      include Whodunit::MigrationHelpers

      def self.name = "CreateTestTable"

      def add_column(table, column, type, **options)
        (@added_columns ||= []) << { table: table, column: column, type: type, options: options }
      end

      def remove_column(table, column)
        (@removed_columns ||= []) << { table: table, column: column }
      end

      def column_exists?(table, column)
        (@existing_columns ||= {}).dig(table, column) || false
      end

      def table_exists?(_table) = true

      def add_index(table, column, **options)
        (@added_indexes ||= []) << { table: table, column: column, options: options }
      end

      attr_reader :added_columns, :removed_columns, :added_indexes

      def set_existing_columns(table, columns)
        @existing_columns ||= {}
        @existing_columns[table] = columns.index_with { true }
      end

      attr_writer :existing_tables, :migration_name

      def migration_name = @migration_name || self.class.name.split("::").last
    end.new
  end

  # fake connection for TableDefinition instantiation

  let(:fake_conn) do
    Object.new.tap do |c|
      def c.supports_datetime_with_precision? = false
      def c.native_database_types = { datetime: { name: "datetime" }, primary_key: { name: "bigint" } }
    end
  end

  # Real TableDefinition instance – exercises genuine `column` / `index` paths
  let(:table_def) do
    ActiveRecord::ConnectionAdapters::TableDefinition.new(fake_conn, "posts")
  end

  # #add_whodunit_stamps

  describe "#add_whodunit_stamps" do
    it "adds creator and updater columns with default types" do
      migration_recorder.add_whodunit_stamps(:users)

      expect(migration_recorder.added_columns).to include(
        { table: :users, column: :creator_id, type: :bigint, options: { null: true } },
        { table: :users, column: :updater_id, type: :bigint, options: { null: true } }
      )
    end

    it "accepts custom column types" do
      migration_recorder.add_whodunit_stamps(:users,
                                             creator_type: :string,
                                             updater_type: :uuid,
                                             deleter_type: :integer)

      expect(migration_recorder.added_columns).to include(
        { table: :users, column: :creator_id, type: :string, options: { null: true } },
        { table: :users, column: :updater_id, type: :uuid,   options: { null: true } }
      )
    end

    it "adds deleter column when include_deleter: true" do
      migration_recorder.add_whodunit_stamps(:users, include_deleter: true)

      expect(migration_recorder.added_columns).to include(
        { table: :users, column: :deleter_id, type: :bigint, options: { null: true } }
      )
    end

    it "adds deleter column when soft-delete is configured (include_deleter: :auto)" do
      Whodunit.soft_delete_column = :deleted_at
      migration_recorder.add_whodunit_stamps(:users, include_deleter: :auto)

      expect(migration_recorder.added_columns).to include(
        { table: :users, column: :deleter_id, type: :bigint, options: { null: true } }
      )
    ensure
      Whodunit.soft_delete_column = nil
    end

    it "does not add deleter column when soft-delete is not configured" do
      Whodunit.soft_delete_column = nil
      migration_recorder.add_whodunit_stamps(:users, include_deleter: :auto)

      deleter_cols = (migration_recorder.added_columns || []).select { |c| c[:column] == :deleter_id }
      expect(deleter_cols).to be_empty
    end
  end

  # #remove_whodunit_stamps

  describe "#remove_whodunit_stamps" do
    it "removes existing stamp columns" do
      migration_recorder.set_existing_columns(:users, %i[creator_id updater_id])
      migration_recorder.remove_whodunit_stamps(:users)

      expect(migration_recorder.removed_columns).to include(
        { table: :users, column: :creator_id },
        { table: :users, column: :updater_id }
      )
    end

    it "does not attempt to remove columns that do not exist" do
      migration_recorder.remove_whodunit_stamps(:users)
      expect(migration_recorder.removed_columns || []).to be_empty
    end

    it "removes deleter column when soft-delete is configured" do
      Whodunit.soft_delete_column = :deleted_at
      migration_recorder.set_existing_columns(:users, %i[creator_id updater_id deleter_id])
      migration_recorder.remove_whodunit_stamps(:users, include_deleter: :auto)

      expect(migration_recorder.removed_columns).to include(
        { table: :users, column: :deleter_id }
      )
    ensure
      Whodunit.soft_delete_column = nil
    end
  end

  # #whodunit_stamps (table definition path)
  # Uses a REAL TableDefinition – no doubles needed.

  describe "#whodunit_stamps with a table definition" do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      ActiveRecord::ConnectionAdapters::TableDefinition.extend(described_class) unless
        ActiveRecord::ConnectionAdapters::TableDefinition.singleton_class.ancestors
                                                         .include?(described_class)
    end

    it "adds creator_id and updater_id columns to the table definition" do
      migration_recorder.whodunit_stamps(table_def)
      column_names = table_def.columns.map(&:name)
      expect(column_names).to include("creator_id", "updater_id")
    end

    it "accepts custom column types" do
      migration_recorder.whodunit_stamps(table_def, creator_type: :string, updater_type: :uuid)
      col = table_def.columns.find { |c| c.name == "creator_id" }
      expect(col.type).to eq(:string)
    end

    it "does not add deleter column by default (include_deleter: :auto, no soft delete config)" do
      Whodunit.soft_delete_column = nil
      migration_recorder.whodunit_stamps(table_def, include_deleter: :auto)
      column_names = table_def.columns.map(&:name)
      expect(column_names).not_to include("deleter_id")
    end

    it "adds deleter column when include_deleter: true" do
      migration_recorder.whodunit_stamps(table_def, include_deleter: true)
      column_names = table_def.columns.map(&:name)
      expect(column_names).to include("deleter_id")
    end
  end

  # #whodunit_stamps (no table def – infer from migration name)

  describe "#whodunit_stamps without a table definition" do
    it "does not raise when called from a migration with an inferable name" do
      expect { migration_recorder.whodunit_stamps }.not_to raise_error
    end
  end

  # private helpers

  describe "private #should_include_deleter?" do
    it "returns true when passed true" do
      expect(migration_recorder.send(:should_include_deleter?, true)).to be true
    end

    it "returns false when passed false" do
      expect(migration_recorder.send(:should_include_deleter?, false)).to be false
    end

    it "returns true for :auto when soft_delete_column is configured" do
      Whodunit.soft_delete_column = :deleted_at
      expect(migration_recorder.send(:should_include_deleter?, :auto)).to be true
    ensure
      Whodunit.soft_delete_column = nil
    end

    it "returns false for :auto when soft_delete_column is nil" do
      Whodunit.soft_delete_column = nil
      expect(migration_recorder.send(:should_include_deleter?, :auto)).to be false
    end
  end

  describe "private #infer_table_name_from_migration" do
    it "infers table name from Create* migration names" do
      migration_recorder.migration_name = "CreateUsers"
      expect(migration_recorder.send(:infer_table_name_from_migration)).to eq("users")
    end

    it "infers table name from AddStampsTo* migration names" do
      migration_recorder.migration_name = "AddStampsToUsers"
      expect(migration_recorder.send(:infer_table_name_from_migration)).to eq("users")
    end

    it "returns nil for unrecognised migration class names" do
      migration_recorder.migration_name = "SomeRandomMigration"
      expect(migration_recorder.send(:infer_table_name_from_migration)).to be_nil
    end
  end
end
