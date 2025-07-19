# frozen_string_literal: true

RSpec.describe Whodunit::MigrationHelpers do
  let(:migration_class) do
    Class.new do
      include Whodunit::MigrationHelpers

      def self.name
        "CreateTestTable"
      end

      # Mock migration methods
      def add_column(table, column, type, **options)
        @added_columns ||= []
        @added_columns << { table: table, column: column, type: type, options: options }
      end

      def remove_column(table, column)
        @removed_columns ||= []
        @removed_columns << { table: table, column: column }
      end

      def column_exists?(table, column)
        @existing_columns ||= {}
        @existing_columns.dig(table, column) || false
      end

      def table_exists?(table)
        @existing_tables ||= []
        @existing_tables.include?(table)
      end

      def add_index(table, column, **options)
        @added_indexes ||= []
        @added_indexes << { table: table, column: column, options: options }
      end

      # Accessors for testing
      attr_reader :added_columns, :removed_columns, :added_indexes

      def set_existing_columns(table, columns)
        @existing_columns ||= {}
        @existing_columns[table] = columns.index_with { true }
      end

      attr_writer :existing_tables

      attr_writer :migration_name

      def migration_name
        @migration_name || self.class.name.split("::").last
      end
    end
  end

  let(:migration) { migration_class.new }

  describe "#add_whodunit_stamps" do
    it "adds creator and updater columns with default types" do
      migration.add_whodunit_stamps(:users)

      expect(migration.added_columns).to include(
        { table: :users, column: :creator_id, type: :bigint, options: { null: true } },
        { table: :users, column: :updater_id, type: :bigint, options: { null: true } }
      )
    end

    it "adds custom column types when specified" do
      migration.add_whodunit_stamps(:users,
                                    creator_type: :string,
                                    updater_type: :uuid,
                                    deleter_type: :integer)

      expect(migration.added_columns).to include(
        { table: :users, column: :creator_id, type: :string, options: { null: true } },
        { table: :users, column: :updater_id, type: :uuid, options: { null: true } }
      )
    end

    it "adds deleter column when include_deleter is true" do
      migration.add_whodunit_stamps(:users, include_deleter: true)

      expect(migration.added_columns).to include(
        { table: :users, column: :deleter_id, type: :bigint, options: { null: true } }
      )
    end

    it "auto-detects deleter need when soft-delete columns exist" do
      migration.existing_tables = [:users]
      migration.set_existing_columns(:users, [:deleted_at])
      migration.add_whodunit_stamps(:users, include_deleter: :auto)

      expect(migration.added_columns).to include(
        { table: :users, column: :deleter_id, type: :bigint, options: { null: true } }
      )
    end

    it "does not add deleter column when no soft-delete detected" do
      migration.set_existing_columns(:users, [:created_at])
      migration.add_whodunit_stamps(:users, include_deleter: :auto)

      deleter_columns = migration.added_columns.select { |col| col[:column] == :deleter_id }
      expect(deleter_columns).to be_empty
    end
  end

  describe "#remove_whodunit_stamps" do
    it "removes existing stamp columns" do
      migration.set_existing_columns(:users, %i[creator_id updater_id])
      migration.remove_whodunit_stamps(:users)

      expect(migration.removed_columns).to include(
        { table: :users, column: :creator_id },
        { table: :users, column: :updater_id }
      )
    end

    it "does not try to remove non-existent columns" do
      migration.remove_whodunit_stamps(:users)

      expect(migration.removed_columns || []).to be_empty
    end

    it "removes deleter column when it exists and should be included" do
      migration.existing_tables = [:users]
      migration.set_existing_columns(:users, %i[creator_id updater_id deleter_id deleted_at])
      migration.remove_whodunit_stamps(:users, include_deleter: :auto)

      expect(migration.removed_columns).to include(
        { table: :users, column: :deleter_id }
      )
    end
  end

  describe "#whodunit_stamps" do
    context "when called with table definition" do
      let(:table_definition) do
        double("TableDefinition").tap do |t|
          allow(t).to receive(:column)
          allow(t).to receive(:index)
        end
      end

      it "adds columns to table definition with default types" do
        migration.whodunit_stamps(table_definition)

        expect(table_definition).to have_received(:column).with(:creator_id, :bigint, null: true)
        expect(table_definition).to have_received(:column).with(:updater_id, :bigint, null: true)
      end

      it "adds columns with custom types" do
        migration.whodunit_stamps(table_definition,
                                  creator_type: :string,
                                  updater_type: :uuid)

        expect(table_definition).to have_received(:column).with(:creator_id, :string, null: true)
        expect(table_definition).to have_received(:column).with(:updater_id, :uuid, null: true)
      end

      it "does not add deleter column by default for new tables" do
        migration.whodunit_stamps(table_definition, include_deleter: :auto)

        expect(table_definition).not_to have_received(:column).with(:deleter_id, anything, anything)
      end

      it "adds deleter column when explicitly requested" do
        migration.whodunit_stamps(table_definition, include_deleter: true)

        expect(table_definition).to have_received(:column).with(:deleter_id, :bigint, null: true)
      end
    end

    context "when called without table definition" do
      it "attempts to infer table name from migration class" do
        expect { migration.whodunit_stamps }.not_to raise_error
      end
    end
  end

  describe "private helper methods" do
    describe "#should_include_deleter?" do
      it "returns true when include_deleter is true" do
        result = migration.send(:should_include_deleter?, :users, true)
        expect(result).to be true
      end

      it "returns false when include_deleter is false" do
        result = migration.send(:should_include_deleter?, :users, false)
        expect(result).to be false
      end

      it "auto-detects based on table columns when include_deleter is :auto" do
        migration.existing_tables = [:users]
        migration.set_existing_columns(:users, [:deleted_at])

        result = migration.send(:should_include_deleter?, :users, :auto)
        expect(result).to be true
      end

      it "returns false for auto-detect when table doesn't exist" do
        result = migration.send(:should_include_deleter?, :nonexistent, :auto)
        expect(result).to be false
      end
    end

    describe "#infer_table_name_from_migration" do
      it "infers table name from Create migration" do
        migration.migration_name = "CreateUsers"

        result = migration.send(:infer_table_name_from_migration)
        expect(result).to eq("users")
      end

      it "infers table name from AddTo migration" do
        migration.migration_name = "AddStampsToUsers"

        result = migration.send(:infer_table_name_from_migration)
        expect(result).to eq("users")
      end

      it "returns nil for unrecognized migration names" do
        migration.migration_name = "SomeOtherMigration"

        result = migration.send(:infer_table_name_from_migration)
        expect(result).to be_nil
      end
    end
  end
end
