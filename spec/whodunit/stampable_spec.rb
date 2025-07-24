# frozen_string_literal: true

RSpec.describe Whodunit::Stampable do
  let(:user_id) { 123 }

  before do
    Whodunit::Current.user = user_id
  end

  describe "column presence checks" do
    let(:model) { MockActiveRecord.new }

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

  describe "stamping methods" do
    let(:model) { MockActiveRecord.new }

    describe "#set_whodunit_creator" do
      it "sets creator_id when user is present" do
        model.send(:set_whodunit_creator)
        expect(model[:creator_id]).to eq(user_id)
      end

      it "does not set creator_id when no user" do
        Whodunit::Current.user = nil
        model.send(:set_whodunit_creator)
        expect(model[:creator_id]).to be_nil
      end
    end

    describe "#set_whodunit_updater" do
      it "sets updater_id when user is present and not new record" do
        model.save! # Make it not a new record
        # Mock that we're not being soft deleted (simplified approach)
        allow(model).to receive(:being_soft_deleted?).and_return(false)
        model.send(:set_whodunit_updater)
        expect(model[:updater_id]).to eq(user_id)
      end

      it "does not set updater_id on new record" do
        model.send(:set_whodunit_updater)
        expect(model[:updater_id]).to be_nil
      end

      it "does not set updater_id when no user" do
        Whodunit::Current.user = nil
        model.save!
        model.send(:set_whodunit_updater)
        expect(model[:updater_id]).to be_nil
      end

      it "does not set updater_id during soft-delete operation" do
        model.save! # Make it not a new record

        # Mock being_soft_deleted? to return true
        allow(model).to receive(:being_soft_deleted?).and_return(true)

        model.send(:set_whodunit_updater)
        expect(model[:updater_id]).to be_nil
      end
    end

    describe "#set_whodunit_deleter" do
      it "sets deleter_id when user is present" do
        model.send(:set_whodunit_deleter)
        expect(model[Whodunit.deleter_column]).to eq(user_id)
      end

      it "does not set deleter_id when no user" do
        Whodunit::Current.user = nil
        model.send(:set_whodunit_deleter)
        expect(model[Whodunit.deleter_column]).to be_nil
      end
    end

    describe "#being_soft_deleted?" do
      let(:model) { MockSoftDeleteRecord.new }

      context "when deleted_at is being set from nil to timestamp" do
        it "returns true" do
          # Configure deleted_at as the soft delete column for this test
          original_soft_delete_column = Whodunit.soft_delete_column
          Whodunit.soft_delete_column = :deleted_at

          model.save! # Make it persisted
          allow(model).to receive(:attribute_changed?).with("deleted_at").and_return(true)
          allow(model).to receive(:attribute_was).with("deleted_at").and_return(nil)
          allow(model).to receive(:deleted_at).and_return(Time.current)

          expect(model.send(:being_soft_deleted?)).to be true

          # Restore original configuration
          Whodunit.soft_delete_column = original_soft_delete_column
        end
      end

      context "when discarded_at is being set from nil to timestamp" do
        it "returns true" do
          model.save!

          # Configure discarded_at as the soft delete column for this test
          original_soft_delete_column = Whodunit.soft_delete_column
          Whodunit.soft_delete_column = :discarded_at

          # Stub the configured soft delete column check
          allow(model).to receive(:has_attribute?).with("discarded_at").and_return(true)
          allow(model).to receive(:attribute_changed?).with("discarded_at").and_return(true)
          allow(model).to receive(:attribute_was).with("discarded_at").and_return(nil)
          allow(model).to receive(:discarded_at).and_return(Time.current)

          # Also stub the deleter column check
          allow(model).to receive(:has_attribute?).with(Whodunit.deleter_column.to_s).and_return(true)
          allow(model).to receive(:attribute_changed?).with(Whodunit.deleter_column.to_s).and_return(false)

          expect(model.send(:being_soft_deleted?)).to be true

          # Restore original configuration
          Whodunit.soft_delete_column = original_soft_delete_column
        end
      end

      context "when archived_at is being set from nil to timestamp" do
        it "returns true" do
          model.save!

          # Configure archived_at as the soft delete column for this test
          original_soft_delete_column = Whodunit.soft_delete_column
          Whodunit.soft_delete_column = :archived_at

          # Stub the configured soft delete column check
          allow(model).to receive(:has_attribute?).with("archived_at").and_return(true)
          allow(model).to receive(:attribute_changed?).with("archived_at").and_return(true)
          allow(model).to receive(:attribute_was).with("archived_at").and_return(nil)
          allow(model).to receive(:archived_at).and_return(Time.current)

          # Also stub the deleter column check
          allow(model).to receive(:has_attribute?).with(Whodunit.deleter_column.to_s).and_return(true)
          allow(model).to receive(:attribute_changed?).with(Whodunit.deleter_column.to_s).and_return(false)

          expect(model.send(:being_soft_deleted?)).to be true

          # Restore original configuration
          Whodunit.soft_delete_column = original_soft_delete_column
        end
      end

      context "when no soft-delete columns are being changed" do
        it "returns false" do
          model.save!
          allow(model).to receive(:has_attribute?).and_return(false)

          expect(model.send(:being_soft_deleted?)).to be false
        end
      end

      context "when deleted_at is being changed from timestamp to nil (restore)" do
        it "returns false" do
          model.save!
          # Configure deleted_at as the soft delete column for this test
          original_soft_delete_column = Whodunit.soft_delete_column
          Whodunit.soft_delete_column = :deleted_at

          # Mock a restore operation (timestamp to nil) - this should NOT be detected as soft delete
          allow(model).to receive(:attribute_changed?).with("deleted_at").and_return(true)
          allow(model).to receive(:attribute_was).with("deleted_at").and_return(Time.current)
          allow(model).to receive(:deleted_at).and_return(nil)

          expect(model.send(:being_soft_deleted?)).to be false

          # Restore original configuration
          Whodunit.soft_delete_column = original_soft_delete_column
        end
      end

      context "when soft-delete column is being updated to a different timestamp" do
        it "returns false" do
          model.save!
          old_time = 1.hour.ago
          new_time = Time.current

          # Configure deleted_at as the soft delete column for this test
          original_soft_delete_column = Whodunit.soft_delete_column
          Whodunit.soft_delete_column = :deleted_at

          # Mock updating from one timestamp to another (not a delete) - should NOT be detected as soft delete
          allow(model).to receive(:attribute_changed?).with("deleted_at").and_return(true)
          allow(model).to receive(:attribute_was).with("deleted_at").and_return(old_time)
          allow(model).to receive(:deleted_at).and_return(new_time)

          expect(model.send(:being_soft_deleted?)).to be false

          # Restore original configuration
          Whodunit.soft_delete_column = original_soft_delete_column
        end
      end

      context "when no user is set" do
        it "returns false" do
          Whodunit::Current.user = nil
          model.save!

          expect(model.send(:being_soft_deleted?)).to be false
        end
      end

      context "when model has no deleter column" do
        let(:model) do
          Class.new(MockActiveRecord) do
            def self.column_names
              %w[id creator_id updater_id created_at updated_at]
            end
          end.new
        end

        it "returns false" do
          expect(model.send(:being_soft_deleted?)).to be false
        end
      end
    end
  end

  describe "soft delete detection" do
    it "detects soft delete when configured" do
      # Configure soft delete column to enable soft delete support
      original_soft_delete_column = Whodunit.soft_delete_column
      Whodunit.soft_delete_column = :deleted_at

      expect(MockSoftDeleteRecord.soft_delete_enabled?).to be true

      # Restore original configuration
      Whodunit.soft_delete_column = original_soft_delete_column
    end

    it "does not detect soft delete when not configured" do
      # Ensure soft delete column is not configured
      original_soft_delete_column = Whodunit.soft_delete_column
      Whodunit.soft_delete_column = nil

      expect(MockActiveRecord.soft_delete_enabled?).to be false

      # Restore original configuration
      Whodunit.soft_delete_column = original_soft_delete_column
    end
  end

  describe "class methods" do
    let(:model_class) do
      Class.new(MockActiveRecord) do
        def self.skip_callback(*args); end
        def self.before_destroy(*args); end
      end
    end

    describe ".enable_whodunit_deleter!" do
      it "enables deleter tracking for both hard and soft deletes" do
        allow(model_class).to receive(:before_destroy)
        allow(model_class).to receive(:before_update)
        allow(model_class).to receive(:setup_deleter_association)

        model_class.enable_whodunit_deleter!

        expect(model_class).to have_received(:before_destroy).with(:set_whodunit_deleter, if: :deleter_column?)
        expect(model_class).to have_received(:before_update).with(:set_whodunit_deleter, if: :being_soft_deleted?)
        expect(model_class).to have_received(:setup_deleter_association)
        expect(model_class.soft_delete_enabled?).to be true
      end
    end

    describe ".disable_whodunit_deleter!" do
      it "disables deleter tracking for both hard and soft deletes" do
        allow(model_class).to receive(:skip_callback)

        model_class.disable_whodunit_deleter!

        expect(model_class).to have_received(:skip_callback).with(:destroy, :before, :set_whodunit_deleter)
        expect(model_class).to have_received(:skip_callback).with(:update, :before, :set_whodunit_deleter)
        expect(model_class.soft_delete_enabled?).to be false
      end
    end

    describe "private methods" do
      describe ".setup_whodunit_associations" do
        it "sets up associations based on available columns" do
          model_with_all_columns = Class.new(MockActiveRecord) do
            def self.column_names
              %w[id creator_id updater_id deleter_id created_at updated_at deleted_at]
            end

            def self.soft_delete_enabled?
              true
            end
          end

          allow(model_with_all_columns).to receive(:setup_creator_association)
          allow(model_with_all_columns).to receive(:setup_updater_association)
          allow(model_with_all_columns).to receive(:setup_deleter_association)

          model_with_all_columns.send(:setup_whodunit_associations)

          expect(model_with_all_columns).to have_received(:setup_creator_association)
          expect(model_with_all_columns).to have_received(:setup_updater_association)
          expect(model_with_all_columns).to have_received(:setup_deleter_association)
        end
      end
    end
  end

  describe "integration scenarios" do
    let(:model) { MockSoftDeleteRecord.new }

    describe "soft-delete guardrail" do
      it "prevents updater_id from being overwritten during soft-delete" do
        # Setup: Create and update a record to set initial updater
        initial_user_id = 100
        deleting_user_id = 200

        # Initial creation and update
        Whodunit::Current.user = initial_user_id
        model.save!
        # Mock that this is a normal update (not being soft deleted)
        allow(model).to receive(:being_soft_deleted?).and_return(false)
        model.send(:set_whodunit_updater) # Simulate normal update
        expect(model[:updater_id]).to eq(initial_user_id)

        # Soft-delete scenario
        Whodunit::Current.user = deleting_user_id

        # Mock soft-delete detection
        allow(model).to receive(:being_soft_deleted?).and_return(true)

        # Simulate what would happen during a soft-delete update
        model.send(:set_whodunit_updater) # Should NOT update updater_id
        model.send(:set_whodunit_deleter) # Should set deleter_id

        # Verify the guardrail worked
        expect(model[:updater_id]).to eq(initial_user_id) # Preserved!
        expect(model[Whodunit.deleter_column]).to eq(deleting_user_id) # Set correctly
      end
    end

    describe "dual callback coverage" do
      it "tracks deleter for hard delete via before_destroy" do
        model.save!

        # Mock NOT being a soft-delete
        allow(model).to receive(:being_soft_deleted?).and_return(false)

        model.send(:set_whodunit_deleter)
        expect(model[Whodunit.deleter_column]).to eq(user_id)
      end

      it "tracks deleter for soft delete via before_update" do
        model.save!

        # Mock being a soft-delete
        allow(model).to receive(:being_soft_deleted?).and_return(true)

        model.send(:set_whodunit_deleter)
        expect(model[Whodunit.deleter_column]).to eq(user_id)
      end
    end
  end

  describe "reverse association management" do
    let(:model_class) { Class.new(MockActiveRecord) }

    describe ".disable_whodunit_reverse_associations!" do
      it "disables reverse associations for the model" do
        expect(model_class.whodunit_reverse_associations_enabled?).to be true
        model_class.disable_whodunit_reverse_associations!
        expect(model_class.whodunit_reverse_associations_enabled?).to be false
      end
    end

    describe ".whodunit_reverse_associations_enabled?" do
      it "returns true by default" do
        expect(model_class.whodunit_reverse_associations_enabled?).to be true
      end

      it "returns false after being disabled" do
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
      let(:new_model_class) { Class.new }

      before do
        # Mock the necessary methods for the new model class
        allow(new_model_class).to receive(:before_create)
        allow(new_model_class).to receive(:before_update)
        allow(new_model_class).to receive(:before_destroy)
        allow(new_model_class).to receive(:belongs_to)
        allow(new_model_class).to receive_messages(column_names: %w[id creator_id updater_id deleter_id], included_modules: [])

        # Reset registered models
        Whodunit.registered_models.clear
      end

      it "registers the model when Stampable is included" do
        expect(Whodunit).to receive(:register_model).with(new_model_class)
        new_model_class.include(described_class)
      end
    end
  end
end
