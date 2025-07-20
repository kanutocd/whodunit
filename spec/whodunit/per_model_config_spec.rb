# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass
RSpec.describe "Per-model configuration" do
  let(:user_id) { 123 }

  before do
    Whodunit::Current.user = user_id
  end

  describe "model-specific column configuration" do
    let(:custom_model) do
      Class.new(MockActiveRecord) do
        def self.name
          "CustomModel"
        end

        def self.column_names
          %w[id created_by_id modified_by_id removed_by_id deleted_at created_at updated_at]
        end

        # Configure per-model settings
        whodunit_config do |config|
          config[:creator_column] = :created_by_id
          config[:updater_column] = :modified_by_id
          config[:deleter_column] = :removed_by_id
          config[:user_class] = "Account"
          config[:soft_delete_column] = :deleted_at # Enable soft delete
        end
      end
    end

    it "uses model-specific column names instead of global defaults" do
      expect(custom_model.whodunit_setting(:creator_column)).to eq(:created_by_id)
      expect(custom_model.whodunit_setting(:updater_column)).to eq(:modified_by_id)
      expect(custom_model.whodunit_setting(:deleter_column)).to eq(:removed_by_id)
      expect(custom_model.whodunit_setting(:user_class)).to eq("Account")
    end

    it "falls back to global defaults for non-overridden settings" do
      expect(custom_model.whodunit_setting(:column_data_type)).to eq(Whodunit.column_data_type)
    end

    it "sets up creator association with custom column name" do
      allow(custom_model).to receive(:belongs_to)

      custom_model.send(:setup_whodunit_associations)

      expect(custom_model).to have_received(:belongs_to).with(
        :creator,
        class_name: "Account",
        foreign_key: :created_by_id,
        optional: true
      )
    end

    it "sets up updater association with custom column name" do
      allow(custom_model).to receive(:belongs_to)

      custom_model.send(:setup_whodunit_associations)

      expect(custom_model).to have_received(:belongs_to).with(
        :updater,
        class_name: "Account",
        foreign_key: :modified_by_id,
        optional: true
      )
    end

    it "sets up deleter association with custom column name" do
      allow(custom_model).to receive(:belongs_to)

      custom_model.send(:setup_whodunit_associations)

      expect(custom_model).to have_received(:belongs_to).with(
        :deleter,
        class_name: "Account",
        foreign_key: :removed_by_id,
        optional: true
      )
    end

    it "uses custom columns in stamping methods" do
      instance = custom_model.new

      instance.send(:set_whodunit_creator)
      expect(instance[:created_by_id]).to eq(user_id)

      instance.save!
      instance.send(:set_whodunit_updater)
      expect(instance[:modified_by_id]).to eq(user_id)

      instance.send(:set_whodunit_deleter)
      expect(instance[:removed_by_id]).to eq(user_id)
    end
  end

  describe "model-specific column enabling/disabling" do
    let(:creator_only_model) do
      Class.new(MockActiveRecord) do
        def self.name
          "CreatorOnlyModel"
        end

        def self.column_names
          %w[id creator_id created_at updated_at]
        end

        # Disable updater and deleter for this model
        whodunit_config do |config|
          config[:updater_column] = nil
          config[:deleter_column] = nil
        end
      end
    end

    it "respects per-model column disabling" do
      expect(creator_only_model.model_creator_enabled?).to be true
      expect(creator_only_model.model_updater_enabled?).to be false
      expect(creator_only_model.model_deleter_enabled?).to be false
    end

    it "only sets up associations for enabled columns" do
      allow(creator_only_model).to receive(:belongs_to)

      creator_only_model.send(:setup_whodunit_associations)

      expect(creator_only_model).to have_received(:belongs_to).with(
        :creator,
        class_name: "User",
        foreign_key: :creator_id,
        optional: true
      ).once

      # Should not set up updater or deleter associations
      expect(creator_only_model).not_to have_received(:belongs_to).with(
        hash_including(foreign_key: :updater_id)
      )
      expect(creator_only_model).not_to have_received(:belongs_to).with(
        hash_including(foreign_key: :deleter_id)
      )
    end

    it "only stamps enabled columns" do
      instance = creator_only_model.new

      # Creator should work
      expect(instance.creator_column?).to be true
      instance.send(:set_whodunit_creator)
      expect(instance[:creator_id]).to eq(user_id)

      # Updater and deleter should be disabled
      expect(instance.updater_column?).to be false
      expect(instance.deleter_column?).to be false
    end
  end

  describe "model-specific soft delete configuration" do
    let(:soft_delete_model) do
      Class.new(MockActiveRecord) do
        def self.name
          "SoftDeleteModel"
        end

        def self.column_names
          %w[id creator_id updater_id deleter_id archived_at created_at updated_at]
        end

        # Configure custom soft delete column
        whodunit_config do |config|
          config[:soft_delete_column] = :archived_at
        end
      end
    end

    it "uses model-specific soft delete column" do
      expect(soft_delete_model.whodunit_setting(:soft_delete_column)).to eq(:archived_at)
      expect(soft_delete_model.model_soft_delete_enabled?).to be true
    end

    it "detects soft delete with custom column" do
      instance = soft_delete_model.new
      instance.save!

      # Mock the soft delete scenario
      allow(instance).to receive(:attribute_changed?).with("archived_at").and_return(true)
      allow(instance).to receive(:attribute_was).with("archived_at").and_return(nil)
      allow(instance).to receive(:archived_at).and_return(Time.current)

      expect(instance.send(:being_soft_deleted?)).to be true
    end
  end

  describe "configuration inheritance" do
    it "does not affect other models when one model has custom config" do
      # Create a model with custom config
      custom_model = Class.new(MockActiveRecord) do
        def self.name
          "CustomModel"
        end

        whodunit_config do |config|
          config[:creator_column] = :custom_creator_id
        end
      end

      # Create a normal model
      normal_model = Class.new(MockActiveRecord) do
        def self.name
          "NormalModel"
        end
      end

      # Custom model should use custom setting
      expect(custom_model.whodunit_setting(:creator_column)).to eq(:custom_creator_id)

      # Normal model should use global default
      expect(normal_model.whodunit_setting(:creator_column)).to eq(Whodunit.creator_column)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
