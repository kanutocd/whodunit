# frozen_string_literal: true

RSpec.describe Whodunit do
  it "has a version number" do
    expect(Whodunit::VERSION).not_to be_nil
  end

  describe "configuration" do
    it "has default user class" do
      expect(described_class.user_class).to eq("User")
    end

    it "has default column names" do
      expect(described_class.creator_column).to eq(:creator_id)
      expect(described_class.updater_column).to eq(:updater_id)
      expect(described_class.deleter_column).to eq(:deleter_id)
    end

    it "has default column data types" do
      expect(described_class.column_data_type).to eq(:bigint)
      expect(described_class.creator_column_type).to be_nil
      expect(described_class.updater_column_type).to be_nil
      expect(described_class.deleter_column_type).to be_nil
    end

    it "has default soft delete column configured" do
      expect(described_class.soft_delete_column).to be_nil
    end

    it "has auto-injection enabled by default" do
      expect(described_class.auto_inject_whodunit_stamps).to be(true)
    end

    it "has reverse associations enabled by default" do
      expect(described_class.auto_setup_reverse_associations).to be(true)
    end

    it "has empty reverse association prefix and suffix by default" do
      expect(described_class.reverse_association_prefix).to eq("")
      expect(described_class.reverse_association_suffix).to eq("")
    end

    it "starts with an empty registered models array" do
      # Clear any models that may have been registered by other tests
      described_class.registered_models.clear
      expect(described_class.registered_models).to eq([])
    end

    it "allows configuration" do
      described_class.configure do |config|
        config.user_class = "Account"
        config.creator_column = :created_by_id
        config.column_data_type = :integer
        config.creator_column_type = :string
      end

      expect(described_class.user_class).to eq("Account")
      expect(described_class.creator_column).to eq(:created_by_id)
      expect(described_class.column_data_type).to eq(:integer)
      expect(described_class.creator_column_type).to eq(:string)

      # Reset for other tests
      described_class.user_class = "User"
      described_class.creator_column = :creator_id
      described_class.column_data_type = :bigint
      described_class.creator_column_type = nil
    end
  end

  describe ".user_class_name" do
    it "returns string version of user class" do
      expect(described_class.user_class_name).to eq("User")
    end
  end

  describe "data type helpers" do
    it "returns configured data type when specific type is nil" do
      expect(described_class.creator_data_type).to eq(:bigint)
      expect(described_class.updater_data_type).to eq(:bigint)
      expect(described_class.deleter_data_type).to eq(:bigint)
    end

    it "returns specific type when configured" do
      described_class.creator_column_type = :string
      described_class.updater_column_type = :integer
      described_class.deleter_column_type = :uuid

      expect(described_class.creator_data_type).to eq(:string)
      expect(described_class.updater_data_type).to eq(:integer)
      expect(described_class.deleter_data_type).to eq(:uuid)

      # Reset for other tests
      described_class.creator_column_type = nil
      described_class.updater_column_type = nil
      described_class.deleter_column_type = nil
    end

    it "falls back to general data type when specific type is nil" do
      described_class.column_data_type = :integer

      expect(described_class.creator_data_type).to eq(:integer)
      expect(described_class.updater_data_type).to eq(:integer)
      expect(described_class.deleter_data_type).to eq(:integer)

      # Reset for other tests
      described_class.column_data_type = :bigint
    end
  end

  describe ".soft_delete_enabled?" do
    it "returns false when soft_delete_column is nil" do
      original_soft_delete_column = described_class.soft_delete_column
      described_class.soft_delete_column = nil

      expect(described_class.soft_delete_enabled?).to be false

      described_class.soft_delete_column = original_soft_delete_column
    end

    it "returns true when soft_delete_column is configured" do
      original_soft_delete_column = described_class.soft_delete_column
      described_class.soft_delete_column = :deleted_at

      expect(described_class.soft_delete_enabled?).to be true

      described_class.soft_delete_column = original_soft_delete_column
    end
  end

  describe "column enabling/disabling" do
    describe ".creator_enabled?" do
      it "returns true when creator_column is not nil" do
        original_creator_column = described_class.creator_column
        described_class.creator_column = :created_by_id

        expect(described_class.creator_enabled?).to be true

        described_class.creator_column = original_creator_column
      end

      it "returns false when creator_column is nil" do
        original_creator_column = described_class.creator_column
        described_class.creator_column = nil

        expect(described_class.creator_enabled?).to be false

        described_class.creator_column = original_creator_column
      end
    end

    describe ".updater_enabled?" do
      it "returns true when updater_column is not nil" do
        original_updater_column = described_class.updater_column
        described_class.updater_column = :updated_by_id

        expect(described_class.updater_enabled?).to be true

        described_class.updater_column = original_updater_column
      end

      it "returns false when updater_column is nil" do
        original_updater_column = described_class.updater_column
        described_class.updater_column = nil

        expect(described_class.updater_enabled?).to be false

        described_class.updater_column = original_updater_column
      end
    end

    describe ".deleter_enabled?" do
      it "returns true when deleter_column is not nil" do
        original_deleter_column = described_class.deleter_column
        described_class.deleter_column = :deleted_by_id

        expect(described_class.deleter_enabled?).to be true

        described_class.deleter_column = original_deleter_column
      end

      it "returns false when deleter_column is nil" do
        original_deleter_column = described_class.deleter_column
        described_class.deleter_column = nil

        expect(described_class.deleter_enabled?).to be false

        described_class.deleter_column = original_deleter_column
      end
    end
  end

  describe "configuration validation" do
    it "allows disabling creator_column if updater_column is enabled" do
      expect do
        described_class.configure do |config|
          config.creator_column = nil
          config.updater_column = :updated_by_id
        end
      end.not_to raise_error

      # Reset for other tests
      described_class.creator_column = :creator_id
      described_class.updater_column = :updater_id
    end

    it "allows disabling updater_column if creator_column is enabled" do
      expect do
        described_class.configure do |config|
          config.creator_column = :created_by_id
          config.updater_column = nil
        end
      end.not_to raise_error

      # Reset for other tests
      described_class.creator_column = :creator_id
      described_class.updater_column = :updater_id
    end

    it "raises error when both creator_column and updater_column are nil" do
      expect do
        described_class.configure do |config|
          config.creator_column = nil
          config.updater_column = nil
        end
      end.to raise_error(Whodunit::Error, /At least one of creator_column or updater_column must be configured/)

      # Reset for other tests
      described_class.creator_column = :creator_id
      described_class.updater_column = :updater_id
    end

    it "allows disabling deleter_column independently" do
      expect do
        described_class.configure do |config|
          config.deleter_column = nil
        end
      end.not_to raise_error

      # Reset for other tests
      described_class.deleter_column = :deleter_id
    end
  end
end
