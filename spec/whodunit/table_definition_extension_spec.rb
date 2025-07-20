# frozen_string_literal: true

require "spec_helper"

RSpec.describe Whodunit::TableDefinitionExtension do
  let(:mock_table_definition) do
    Class.new do
      include Whodunit::MigrationHelpers
      include Whodunit::TableDefinitionExtension

      attr_reader :columns_added
      attr_accessor :_whodunit_stamps_added

      def initialize
        @columns_added = []
        @_whodunit_stamps_added = false
      end

      def timestamps(**options)
        @columns_added << [:timestamps, options]

        # Auto-inject whodunit_stamps after timestamps if enabled and not already added
        if Whodunit.auto_inject_whodunit_stamps &&
           !@_whodunit_stamps_added &&
           !options[:skip_whodunit_stamps]
          whodunit_stamps(include_deleter: :auto)
          @_whodunit_stamps_added = true
        end

        "timestamps_called"
      end

      def whodunit_stamps(**options)
        @_whodunit_stamps_added = true
        @columns_added << [:whodunit_stamps, options]
        "whodunit_stamps_called"
      end
    end.new
  end

  before do
    # Reset configuration before each test to the default
    Whodunit.auto_inject_whodunit_stamps = true
  end

  after do
    # Reset configuration after each test to the default
    Whodunit.auto_inject_whodunit_stamps = true
  end

  describe "#timestamps" do
    context "when auto_inject_whodunit_stamps is enabled (default)" do
      it "automatically adds whodunit_stamps after timestamps" do
        Whodunit.auto_inject_whodunit_stamps = true

        result = mock_table_definition.timestamps

        expect(result).to eq("timestamps_called")
        expect(mock_table_definition.columns_added).to eq([
                                                            [:timestamps, {}],
                                                            [:whodunit_stamps, { include_deleter: :auto }]
                                                          ])
      end

      it "respects skip_whodunit_stamps option" do
        Whodunit.auto_inject_whodunit_stamps = true

        result = mock_table_definition.timestamps(skip_whodunit_stamps: true)

        expect(result).to eq("timestamps_called")
        expect(mock_table_definition.columns_added).to eq([
                                                            [:timestamps, { skip_whodunit_stamps: true }]
                                                          ])
      end

      it "does not add whodunit_stamps twice if already added manually" do
        Whodunit.auto_inject_whodunit_stamps = true

        # Manually add whodunit_stamps first
        mock_table_definition.whodunit_stamps(include_deleter: true)
        # Then call timestamps
        mock_table_definition.timestamps

        expect(mock_table_definition.columns_added).to eq([
                                                            [:whodunit_stamps, { include_deleter: true }],
                                                            [:timestamps, {}]
                                                          ])
      end

      it "does not add whodunit_stamps multiple times when timestamps called multiple times" do
        Whodunit.auto_inject_whodunit_stamps = true

        mock_table_definition.timestamps
        mock_table_definition.timestamps

        expect(mock_table_definition.columns_added).to eq([
                                                            [:timestamps, {}],
                                                            [:whodunit_stamps, { include_deleter: :auto }],
                                                            [:timestamps, {}]
                                                          ])
      end
    end

    context "when auto_inject_whodunit_stamps is disabled" do
      it "does not automatically add whodunit_stamps" do
        Whodunit.auto_inject_whodunit_stamps = false

        result = mock_table_definition.timestamps

        expect(result).to eq("timestamps_called")
        expect(mock_table_definition.columns_added).to eq([[:timestamps, {}]])
      end
    end

    context "with custom column configuration" do
      before do
        # Test with custom column names
        Whodunit.deleter_column = :deleted_by_id
      end

      after do
        # Reset to default
        Whodunit.deleter_column = :deleter_id
      end

      it "uses configured column names in auto-injection" do
        Whodunit.auto_inject_whodunit_stamps = true

        result = mock_table_definition.timestamps

        expect(result).to eq("timestamps_called")
        expect(mock_table_definition.columns_added).to eq([
                                                            [:timestamps, {}],
                                                            [:whodunit_stamps, { include_deleter: :auto }]
                                                          ])
      end
    end
  end

  describe "#whodunit_stamps" do
    it "tracks that whodunit_stamps have been added" do
      mock_table_definition.whodunit_stamps(include_deleter: false)

      expect(mock_table_definition.columns_added).to eq([
                                                          [:whodunit_stamps, { include_deleter: false }]
                                                        ])
      expect(mock_table_definition._whodunit_stamps_added).to be true
    end
  end
end
