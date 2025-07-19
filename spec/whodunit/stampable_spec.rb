# frozen_string_literal: true

RSpec.describe Whodunit::Stampable do
  let(:user_id) { 123 }

  before do
    Whodunit::Current.user = user_id
  end

  describe "column presence checks" do
    let(:model) { MockActiveRecord.new }

    it "detects creator column" do
      expect(model.send(:has_creator_column?)).to be true
    end

    it "detects updater column" do
      expect(model.send(:has_updater_column?)).to be true
    end

    it "detects deleter column" do
      expect(model.send(:has_deleter_column?)).to be true
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
    end

    describe "#set_whodunit_deleter" do
      it "sets deleter_id when user is present" do
        model.send(:set_whodunit_deleter)
        expect(model[:deleter_id]).to eq(user_id)
      end

      it "does not set deleter_id when no user" do
        Whodunit::Current.user = nil
        model.send(:set_whodunit_deleter)
        expect(model[:deleter_id]).to be_nil
      end
    end
  end

  describe "soft delete detection" do
    it "detects soft delete on models with deleted_at" do
      expect(MockSoftDeleteRecord.soft_delete_enabled?).to be true
    end

    it "does not detect soft delete on regular models" do
      expect(MockActiveRecord.soft_delete_enabled?).to be false
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
      it "enables deleter tracking" do
        expect(model_class).to receive(:before_destroy).with(:set_whodunit_deleter, if: :has_deleter_column?)
        expect(model_class).to receive(:setup_deleter_association)
        model_class.enable_whodunit_deleter!
        expect(model_class.soft_delete_enabled?).to be true
      end
    end

    describe ".disable_whodunit_deleter!" do
      it "disables deleter tracking" do
        expect(model_class).to receive(:skip_callback).with(:destroy, :before, :set_whodunit_deleter)
        model_class.disable_whodunit_deleter!
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

          expect(model_with_all_columns).to receive(:setup_creator_association)
          expect(model_with_all_columns).to receive(:setup_updater_association)
          expect(model_with_all_columns).to receive(:setup_deleter_association)

          model_with_all_columns.send(:setup_whodunit_associations)
        end
      end
    end
  end
end
