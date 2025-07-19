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

    it "has auto-detect enabled by default" do
      expect(described_class.auto_detect_soft_delete).to be(true)
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
end
