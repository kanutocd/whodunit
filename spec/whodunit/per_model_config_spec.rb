# frozen_string_literal: true

require "spec_helper"

# rubocop:disable RSpec/DescribeClass
RSpec.describe "Per-model configuration" do
  let(:user_id) { 123 }

  before { Whodunit::Current.user = user_id }

  # model-specific column names

  describe "model-specific column configuration" do
    # We need a table that has the custom column names, so we reuse
    # whodunit_records but override whodunit_setting at the class level.
    let(:custom_model) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "whodunit_records"

        include Whodunit::Stampable

        whodunit_config do |cfg|
          cfg[:creator_column] = :creator_id   # already in table
          cfg[:updater_column] = :updater_id   # already in table
          cfg[:deleter_column] = :deleter_id   # already in table
          cfg[:user_class]     = "Account"
        end

        # Re-run association setup now that per-model config is applied.
        # AR caches reflections at include-time, so we need an explicit
        # re-setup after whodunit_config changes the user_class.
        send(:setup_whodunit_associations)
      end
    end

    it "returns model-specific column names from whodunit_setting" do
      expect(custom_model.whodunit_setting(:creator_column)).to eq(:creator_id)
      expect(custom_model.whodunit_setting(:updater_column)).to eq(:updater_id)
      expect(custom_model.whodunit_setting(:deleter_column)).to eq(:deleter_id)
      expect(custom_model.whodunit_setting(:user_class)).to eq("Account")
    end

    it "falls back to global defaults for non-overridden settings" do
      expect(custom_model.whodunit_setting(:column_data_type)).to eq(Whodunit.column_data_type)
    end

    it "sets up the creator belongs_to with the configured class_name" do
      assoc = custom_model.reflect_on_association(:creator)
      expect(assoc).not_to be_nil
      expect(assoc.options[:class_name]).to eq("Account")
    end

    it "sets up the updater belongs_to with the configured class_name" do
      assoc = custom_model.reflect_on_association(:updater)
      expect(assoc).not_to be_nil
      expect(assoc.options[:class_name]).to eq("Account")
    end

    it "stamps using the configured column names" do
      instance = custom_model.new
      instance.send(:set_whodunit_creator)
      expect(instance[:creator_id]).to eq(user_id)

      instance.save!
      instance.send(:set_whodunit_updater)
      expect(instance[:updater_id]).to eq(user_id)

      instance.send(:set_whodunit_deleter)
      expect(instance[:deleter_id]).to eq(user_id)
    end
  end

  # per-model column enabling/disabling

  describe "model-specific column enabling/disabling" do
    let(:creator_only_model) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "whodunit_records"

        # Apply per-model config BEFORE including Stampable so that
        # setup_whodunit_associations (called from the `included` block)
        # already sees the nil updater/deleter columns.
        @whodunit_config_overrides = {
          updater_column: nil,
          deleter_column: nil
        }

        include Whodunit::Stampable
      end
    end

    it "reports creator enabled and updater/deleter disabled" do
      expect(creator_only_model.model_creator_enabled?).to be true
      expect(creator_only_model.model_updater_enabled?).to be false
      expect(creator_only_model.model_deleter_enabled?).to be false
    end

    it "only sets up the creator belongs_to association" do
      expect(creator_only_model.reflect_on_association(:creator)).not_to be_nil
      expect(creator_only_model.reflect_on_association(:updater)).to be_nil
      expect(creator_only_model.reflect_on_association(:deleter)).to be_nil
    end

    it "reports only creator_column? as true on an instance" do
      instance = creator_only_model.new
      expect(instance.creator_column?).to be true
      expect(instance.updater_column?).to be false
      expect(instance.deleter_column?).to be false
    end

    it "stamps only the creator column" do
      instance = creator_only_model.new
      instance.send(:set_whodunit_creator)
      expect(instance[:creator_id]).to eq(user_id)
    end
  end

  # per-model soft-delete configuration

  describe "model-specific soft delete configuration" do
    let(:soft_delete_model) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "whodunit_soft_delete_records"

        include Whodunit::Stampable

        whodunit_config do |cfg|
          cfg[:soft_delete_column] = :deleted_at
        end
      end
    end

    it "reports model-specific soft-delete column via whodunit_setting" do
      expect(soft_delete_model.whodunit_setting(:soft_delete_column)).to eq(:deleted_at)
      expect(soft_delete_model.model_soft_delete_enabled?).to be true
    end

    it "detects soft-delete via real AR dirty tracking" do
      instance = soft_delete_model.create!
      instance.deleted_at = Time.now.utc
      # No stubs – dirty tracking comes from the real AR attribute system
      expect(instance.send(:being_soft_deleted?)).to be true
    end

    it "does not detect soft-delete when the column is being cleared" do
      instance = soft_delete_model.create!(deleted_at: Time.now.utc)
      instance.reload
      instance.deleted_at = nil
      expect(instance.send(:being_soft_deleted?)).to be false
    end
  end

  # configuration isolation between models

  describe "configuration inheritance" do
    it "does not bleed custom settings into sibling models" do
      custom = Class.new(ActiveRecord::Base) do
        self.table_name = "whodunit_records"
        include Whodunit::Stampable

        whodunit_config { |cfg| cfg[:creator_column] = :custom_creator_id }
      end

      normal = Class.new(ActiveRecord::Base) do
        self.table_name = "whodunit_records"
        include Whodunit::Stampable
      end

      expect(custom.whodunit_setting(:creator_column)).to eq(:custom_creator_id)
      expect(normal.whodunit_setting(:creator_column)).to eq(Whodunit.creator_column)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
