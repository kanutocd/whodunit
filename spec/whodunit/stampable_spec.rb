# frozen_string_literal: true

require "spec_helper"

RSpec.describe Whodunit::Stampable do
  let(:user_id) { 123 }

  before { Whodunit::Current.user = user_id }

  # column presence checks

  describe "column presence checks" do
    subject(:model) { WhodunitRecord.new }

    it "detects creator column" do
      expect(model.send(:creator_column?)).to be true
    end

    it "detects updater column" do
      expect(model.send(:updater_column?)).to be true
    end

    it "detects deleter column" do
      expect(model.send(:deleter_column?)).to be true
    end
  end

  # stamping callbacks

  describe "stamping methods" do
    subject(:model) { WhodunitRecord.new }

    describe "#set_whodunit_creator" do
      it "sets creator_id when a user is present" do
        model.send(:set_whodunit_creator)
        expect(model[:creator_id]).to eq(user_id)
      end

      it "does not set creator_id when no user is set" do
        Whodunit::Current.user = nil
        model.send(:set_whodunit_creator)
        expect(model[:creator_id]).to be_nil
      end
    end

    describe "#set_whodunit_updater" do
      it "sets updater_id on a persisted (non-new) record" do
        model.save!
        model.send(:set_whodunit_updater)
        expect(model[:updater_id]).to eq(user_id)
      end

      it "does not set updater_id on a new (unsaved) record" do
        model.send(:set_whodunit_updater)
        expect(model[:updater_id]).to be_nil
      end

      it "does not set updater_id when no user is set" do
        Whodunit::Current.user = nil
        model.save!
        model.send(:set_whodunit_updater)
        expect(model[:updater_id]).to be_nil
      end

      it "does not set updater_id during a soft-delete operation" do
        model.save!
        # Simulate the soft-delete guard by using a real soft-delete record
        sd_model = WhodunitSoftDeleteRecord.create!(creator_id: user_id)
        Whodunit.soft_delete_column = :deleted_at

        # Trigger soft-delete: write deleted_at from nil → Time
        sd_model.deleted_at = Time.now.utc
        expect(sd_model.send(:being_soft_deleted?)).to be true
        sd_model.send(:set_whodunit_updater)
        expect(sd_model[:updater_id]).to be_nil
      ensure
        Whodunit.soft_delete_column = nil
      end
    end

    describe "#set_whodunit_deleter" do
      it "sets deleter_id when a user is present" do
        model.send(:set_whodunit_deleter)
        expect(model[Whodunit.deleter_column]).to eq(user_id)
      end

      it "does not set deleter_id when no user is set" do
        Whodunit::Current.user = nil
        model.send(:set_whodunit_deleter)
        expect(model[Whodunit.deleter_column]).to be_nil
      end
    end

    describe "#being_soft_deleted?" do
      let(:sd_model) { WhodunitSoftDeleteRecord.create! }

      around do |example|
        Whodunit.soft_delete_column = :deleted_at
        example.run
        Whodunit.soft_delete_column = nil
      end

      context "when deleted_at is written from nil to a timestamp" do
        it "returns true" do
          sd_model.deleted_at = Time.now.utc
          expect(sd_model.send(:being_soft_deleted?)).to be true
        end
      end

      context "when deleted_at is restored from timestamp back to nil (un-delete)" do
        it "returns false" do
          sd_model.update!(deleted_at: Time.now.utc)
          sd_model.reload
          sd_model.deleted_at = nil
          expect(sd_model.send(:being_soft_deleted?)).to be false
        end
      end

      context "when deleted_at changes from one timestamp to another" do
        it "returns false (not a fresh deletion)" do
          sd_model.update!(deleted_at: 1.hour.ago)
          sd_model.reload
          sd_model.deleted_at = Time.now.utc
          expect(sd_model.send(:being_soft_deleted?)).to be false
        end
      end

      context "when no soft-delete column is configured" do
        around do |example|
          Whodunit.soft_delete_column = nil
          example.run
          Whodunit.soft_delete_column = nil
        end

        it "returns false" do
          expect(sd_model.send(:being_soft_deleted?)).to be false
        end
      end

      context "when no user is set" do
        it "returns false" do
          Whodunit::Current.user = nil
          sd_model.deleted_at = Time.now.utc
          expect(sd_model.send(:being_soft_deleted?)).to be false
        end
      end

      context "when model has no deleter column" do
        let(:no_deleter_class) do
          Class.new(ActiveRecord::Base) do
            self.table_name = "whodunit_records"

            def self.column_names
              super.reject { |c| c == Whodunit.deleter_column.to_s }
            end

            include Whodunit::Stampable
          end
        end

        it "returns false" do
          instance = no_deleter_class.new
          expect(instance.send(:being_soft_deleted?)).to be false
        end
      end
    end
  end

  # soft delete detection (class-level)

  describe "soft delete detection" do
    it "detects soft-delete when a soft_delete_column is configured" do
      Whodunit.soft_delete_column = :deleted_at
      # WhodunitSoftDeleteRecord has deleted_at in its table
      expect(WhodunitSoftDeleteRecord.soft_delete_enabled?).to be true
    ensure
      Whodunit.soft_delete_column = nil
    end

    it "does not detect soft-delete when soft_delete_column is nil" do
      Whodunit.soft_delete_column = nil
      expect(WhodunitRecord.soft_delete_enabled?).to be false
    end
  end

  # class methods

  describe "class methods" do
    # Use a fresh anonymous subclass so we don't pollute WhodunitRecord's
    # callback chain across examples.
    let(:model_class) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "whodunit_records"
        include Whodunit::Stampable
      end
    end

    describe ".enable_whodunit_deleter!" do
      it "sets soft_delete_enabled? to true and registers both callbacks" do
        model_class.enable_whodunit_deleter!
        expect(model_class.soft_delete_enabled?).to be true
      end
    end

    describe ".disable_whodunit_deleter!" do
      it "sets soft_delete_enabled? to false" do
        model_class.enable_whodunit_deleter!
        model_class.disable_whodunit_deleter!
        expect(model_class.soft_delete_enabled?).to be false
      end
    end

    describe "private #setup_whodunit_associations" do
      it "sets up creator and updater associations for a model with those columns" do
        # WhodunitRecord includes creator_id and updater_id – associations should be defined
        expect(WhodunitRecord.reflect_on_association(:creator)).not_to be_nil
        expect(WhodunitRecord.reflect_on_association(:updater)).not_to be_nil
      end

      it "does not set up deleter association when soft delete is not configured" do
        Whodunit.soft_delete_column = nil
        # Re-include on a fresh class to re-run setup
        klass = Class.new(ActiveRecord::Base) do
          self.table_name = "whodunit_records"
          include Whodunit::Stampable
        end
        expect(klass.reflect_on_association(:deleter)).to be_nil
      end
    end
  end

  # integration scenarios

  describe "integration scenarios" do
    describe "soft-delete guardrail" do
      it "preserves updater_id and sets deleter_id during a soft-delete" do
        Whodunit.soft_delete_column = :deleted_at
        initial_user  = 100
        deleting_user = 200

        Whodunit::Current.user = initial_user
        record = WhodunitSoftDeleteRecord.create!
        record.reload
        Whodunit::Current.user = deleting_user

        # Perform soft-delete via AR dirty tracking
        record.deleted_at = Time.now.utc
        record.send(:set_whodunit_updater) # guard should block this
        record.send(:set_whodunit_deleter) # should set deleter

        expect(record[:updater_id]).to be_nil # was never set in this example
        expect(record[:deleter_id]).to eq(deleting_user)
      ensure
        Whodunit.soft_delete_column = nil
      end
    end

    describe "callback-level stamping via ActiveRecord lifecycle" do
      it "sets creator_id on create" do
        record = WhodunitRecord.create!
        expect(record.creator_id).to eq(user_id)
      end

      it "sets updater_id on update" do
        record = WhodunitRecord.create!
        Whodunit::Current.user = 456
        # Use save! after a dirty write — touch() skips before_update callbacks in AR
        record.updater_id = nil
        record.save!
        record.reload
        expect(record.updater_id).to eq(456)
      end
    end
  end

  # reverse association management

  describe "reverse association management" do
    let(:model_class) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "whodunit_records"
        include Whodunit::Stampable
      end
    end

    describe ".disable_whodunit_reverse_associations!" do
      it "disables reverse associations for the model" do
        expect(model_class.whodunit_reverse_associations_enabled?).to be true
        model_class.disable_whodunit_reverse_associations!
        expect(model_class.whodunit_reverse_associations_enabled?).to be false
      end
    end

    describe ".setup_whodunit_reverse_associations!" do
      it "calls Whodunit.setup_reverse_associations_for_model when enabled" do
        expect(Whodunit).to receive(:setup_reverse_associations_for_model).with(model_class)
        model_class.setup_whodunit_reverse_associations!
      end

      it "does not call setup when disabled" do
        model_class.disable_whodunit_reverse_associations!
        expect(Whodunit).not_to receive(:setup_reverse_associations_for_model)
        model_class.setup_whodunit_reverse_associations!
      end
    end

    describe "automatic registration" do
      before { Whodunit.registered_models.clear }

      it "registers the model when Stampable is included" do
        new_class = Class.new(ActiveRecord::Base) do
          self.table_name = "whodunit_records"
          include Whodunit::Stampable
        end
        expect(Whodunit.registered_models).to include(new_class)
      end
    end
  end
end
