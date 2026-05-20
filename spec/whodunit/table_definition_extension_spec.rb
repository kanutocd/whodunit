# frozen_string_literal: true

require "spec_helper"

RSpec.describe Whodunit::TableDefinitionExtension do
  # helpers

  # Build a real TableDefinition instance backed by a minimal fake connection.
  # We reset the prepend state in a let so each example gets a fresh object.
  let(:conn) do
    Object.new.tap do |c|
      def c.supports_datetime_with_precision? = false

      def c.native_database_types
        { datetime: { name: "datetime" }, primary_key: { name: "bigint" } }
      end
    end
  end
  let(:td) do
    ActiveRecord::ConnectionAdapters::TableDefinition.new(conn, "test_posts").tap do |t|
      # Reset per-example stamp tracker so examples are independent
      t.instance_variable_set(:@_whodunit_stamps_added, false)
    end
  end

  # Ensure the extension is prepended once (idempotent in Ruby).
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    td_class = ActiveRecord::ConnectionAdapters::TableDefinition
    td_class.prepend(described_class) unless
      td_class.ancestors.include?(described_class)
    td_class.extend(Whodunit::MigrationHelpers) unless
      td_class.singleton_class.ancestors.include?(Whodunit::MigrationHelpers)
  end

  before { Whodunit.auto_inject_whodunit_stamps = true }

  # #timestamps

  describe "#timestamps" do
    context "when auto_inject_whodunit_stamps is enabled (default)" do
      it "still adds the real created_at / updated_at columns" do
        td.timestamps
        column_names = td.columns.map(&:name)
        expect(column_names).to include("created_at", "updated_at")
      end

      it "automatically adds whodunit stamp columns after timestamps" do
        td.timestamps
        column_names = td.columns.map(&:name)
        expect(column_names).to include("creator_id", "updater_id")
      end

      it "marks _whodunit_stamps_added as true after auto-injection" do
        td.timestamps
        expect(td._whodunit_stamps_added).to be true
      end

      it "does not add stamp columns twice when whodunit_stamps was already called before timestamps" do
        # Developer manually calls t.whodunit_stamps then t.timestamps in the same block.
        # The extension must not inject a second set of stamp columns.
        td.whodunit_stamps
        stamp_count_before = td.columns.count { |c| c.name == "creator_id" }
        td.timestamps
        stamp_count_after = td.columns.count { |c| c.name == "creator_id" }
        expect(stamp_count_after).to eq(stamp_count_before)
      end

      it "respects skip_whodunit_stamps: true option" do
        td.timestamps(skip_whodunit_stamps: true)
        column_names = td.columns.map(&:name)
        expect(column_names).not_to include("creator_id", "updater_id")
      end
    end

    context "when auto_inject_whodunit_stamps is disabled" do
      before { Whodunit.auto_inject_whodunit_stamps = false }

      it "does not add whodunit stamp columns" do
        td.timestamps
        column_names = td.columns.map(&:name)
        expect(column_names).not_to include("creator_id", "updater_id")
      end

      it "still adds the real created_at / updated_at columns" do
        td.timestamps
        column_names = td.columns.map(&:name)
        expect(column_names).to include("created_at", "updated_at")
      end
    end

    context "with a custom creator column configured" do
      before { Whodunit.creator_column = :created_by_id }
      after  { Whodunit.creator_column = :creator_id }

      it "uses the configured column name" do
        td.timestamps
        column_names = td.columns.map(&:name)
        expect(column_names).to include("created_by_id")
        expect(column_names).not_to include("creator_id")
      end
    end
  end

  # #whodunit_stamps

  describe "#whodunit_stamps" do
    it "adds creator_id and updater_id columns with default types" do
      td.whodunit_stamps
      column_names = td.columns.map(&:name)
      expect(column_names).to include("creator_id", "updater_id")
    end

    it "sets _whodunit_stamps_added to true" do
      td.whodunit_stamps
      expect(td._whodunit_stamps_added).to be true
    end

    it "does not add deleter_id by default (include_deleter: :auto with no soft-delete config)" do
      Whodunit.soft_delete_column = nil
      td.whodunit_stamps(include_deleter: :auto)
      column_names = td.columns.map(&:name)
      expect(column_names).not_to include("deleter_id")
    end

    it "adds deleter_id when include_deleter: true" do
      td.whodunit_stamps(include_deleter: true)
      column_names = td.columns.map(&:name)
      expect(column_names).to include("deleter_id")
    end

    it "uses the configured column data type" do
      Whodunit.column_data_type = :integer
      td.whodunit_stamps
      creator_col = td.columns.find { |c| c.name == "creator_id" }
      expect(creator_col.type).to eq(:integer)
    ensure
      Whodunit.column_data_type = :bigint
    end
  end
end
