# frozen_string_literal: true

RSpec.describe Whodunit do
  let(:user_class) { Class.new }
  let(:model_class) { Class.new }

  before do
    # Reset configuration to defaults
    described_class.auto_setup_reverse_associations = true
    described_class.reverse_association_prefix = ""
    described_class.reverse_association_suffix = ""
    described_class.registered_models.clear

    # Mock user class
    allow(user_class).to receive(:has_many)
    allow(user_class).to receive_messages(reflect_on_association: nil, name: "User")
    allow(user_class).to receive(:respond_to?).with(:has_many).and_return(true)

    # Mock model class
    allow(model_class).to receive_messages(name: "Post", model_creator_enabled?: true, model_updater_enabled?: true, model_deleter_enabled?: true, soft_delete_enabled?: true)
    setting_values = {
      creator_column: :creator_id,
      updater_column: :updater_id,
      deleter_column: :deleter_id
    }
    allow(model_class).to receive(:whodunit_setting) { |key| setting_values[key] }

    # Mock Whodunit.user_class and constantize
    # Mock constantize on the specific string
    allow(described_class).to receive_messages(user_class: "User", resolve_user_class: user_class)
  end

  describe ".register_model" do
    context "when auto_setup_reverse_associations is enabled" do
      it "registers the model" do
        expect { described_class.register_model(model_class) }.to change { described_class.registered_models.size }.by(1)
        expect(described_class.registered_models).to include(model_class)
      end

      it "sets up reverse associations" do
        expect(described_class).to receive(:setup_reverse_associations_for_model).with(model_class)
        described_class.register_model(model_class)
      end

      it "does not register the same model twice" do
        described_class.register_model(model_class)
        expect { described_class.register_model(model_class) }.not_to(change { described_class.registered_models.size })
      end
    end

    context "when auto_setup_reverse_associations is disabled" do
      before { described_class.auto_setup_reverse_associations = false }

      it "does not register the model" do
        expect { described_class.register_model(model_class) }.not_to(change { described_class.registered_models.size })
      end
    end

    context "when model has reverse associations disabled" do
      before do
        allow(model_class).to receive(:respond_to?).with(:whodunit_reverse_associations_enabled?).and_return(true)
        allow(model_class).to receive(:whodunit_reverse_associations_enabled?).and_return(false)
      end

      it "does not register the model" do
        expect { described_class.register_model(model_class) }.not_to(change { described_class.registered_models.size })
      end
    end
  end

  describe ".setup_reverse_associations_for_model" do
    context "when user class exists and responds to has_many" do
      it "sets up creator association" do
        expect(user_class).to receive(:has_many).with(
          :created_posts,
          class_name: "Post",
          dependent: :nullify,
          foreign_key: :creator_id
        ).once
        described_class.setup_reverse_associations_for_model(model_class)
      end

      it "sets up updater association" do
        expect(user_class).to receive(:has_many).with(
          :updated_posts,
          class_name: "Post",
          dependent: :nullify,
          foreign_key: :updater_id
        )
        described_class.setup_reverse_associations_for_model(model_class)
      end

      it "sets up deleter association" do
        expect(user_class).to receive(:has_many).with(
          :deleted_posts,
          class_name: "Post",
          dependent: :nullify,
          foreign_key: :deleter_id
        )
        described_class.setup_reverse_associations_for_model(model_class)
      end

      context "when creator is disabled" do
        before { allow(model_class).to receive(:model_creator_enabled?).and_return(false) }

        it "does not set up creator association" do
          expect(user_class).not_to receive(:has_many).with(
            :created_posts,
            anything
          )
          described_class.setup_reverse_associations_for_model(model_class)
        end
      end

      context "when updater is disabled" do
        before { allow(model_class).to receive(:model_updater_enabled?).and_return(false) }

        it "does not set up updater association" do
          expect(user_class).not_to receive(:has_many).with(
            :updated_posts,
            anything
          )
          described_class.setup_reverse_associations_for_model(model_class)
        end
      end

      context "when deleter is disabled" do
        before { allow(model_class).to receive(:model_deleter_enabled?).and_return(false) }

        it "does not set up deleter association" do
          expect(user_class).not_to receive(:has_many).with(
            :deleted_posts,
            anything
          )
          described_class.setup_reverse_associations_for_model(model_class)
        end
      end

      context "when soft delete is disabled" do
        before { allow(model_class).to receive(:soft_delete_enabled?).and_return(false) }

        it "does not set up deleter association" do
          expect(user_class).not_to receive(:has_many).with(
            :deleted_posts,
            anything
          )
          described_class.setup_reverse_associations_for_model(model_class)
        end
      end

      context "when association already exists" do
        before do
          allow(user_class).to receive(:reflect_on_association).with(:created_posts).and_return(double)
        end

        it "does not set up creator association again" do
          expect(user_class).not_to receive(:has_many).with(
            :created_posts,
            anything
          )
          described_class.setup_reverse_associations_for_model(model_class)
        end
      end
    end

    context "when user class does not exist" do
      before { allow(described_class).to receive(:resolve_user_class).and_return(nil) }

      it "does not set up associations" do
        expect(user_class).not_to receive(:has_many)
        described_class.setup_reverse_associations_for_model(model_class)
      end
    end

    context "when user class does not respond to has_many" do
      before { allow(user_class).to receive(:respond_to?).with(:has_many).and_return(false) }

      it "does not set up associations" do
        expect(user_class).not_to receive(:has_many)
        described_class.setup_reverse_associations_for_model(model_class)
      end
    end

    context "when auto_setup_reverse_associations is disabled" do
      before { described_class.auto_setup_reverse_associations = false }

      it "does not set up associations" do
        expect(user_class).not_to receive(:has_many)
        described_class.setup_reverse_associations_for_model(model_class)
      end
    end
  end

  describe ".generate_reverse_association_name" do
    it "generates basic association name" do
      result = described_class.generate_reverse_association_name("created", "posts")
      expect(result).to eq("created_posts")
    end

    context "with prefix" do
      before { described_class.reverse_association_prefix = "whodunit_" }

      it "includes prefix in association name" do
        result = described_class.generate_reverse_association_name("created", "posts")
        expect(result).to eq("whodunit_created_posts")
      end
    end

    context "with suffix" do
      before { described_class.reverse_association_suffix = "_tracked" }

      it "includes suffix in association name" do
        result = described_class.generate_reverse_association_name("created", "posts")
        expect(result).to eq("created_posts_tracked")
      end
    end

    context "with both prefix and suffix" do
      before do
        described_class.reverse_association_prefix = "whodunit_"
        described_class.reverse_association_suffix = "_tracked"
      end

      it "includes both prefix and suffix in association name" do
        result = described_class.generate_reverse_association_name("created", "posts")
        expect(result).to eq("whodunit_created_posts_tracked")
      end
    end
  end

  describe ".setup_all_reverse_associations" do
    let(:model_class_two) { Class.new }

    before do
      allow(model_class_two).to receive_messages(name: "Comment", model_creator_enabled?: true, model_updater_enabled?: false, model_deleter_enabled?: true, soft_delete_enabled?: true)
      setting_values_two = {
        creator_column: :creator_id,
        deleter_column: :deleter_id
      }
      allow(model_class_two).to receive(:whodunit_setting) { |key| setting_values_two[key] }

      described_class.registered_models.push(model_class, model_class_two)
    end

    it "sets up reverse associations for all registered models" do
      expect(described_class).to receive(:setup_reverse_associations_for_model).with(model_class)
      expect(described_class).to receive(:setup_reverse_associations_for_model).with(model_class_two)
      described_class.setup_all_reverse_associations
    end
  end

  describe "with custom column names" do
    before do
      custom_setting_values = {
        creator_column: :created_by_id,
        updater_column: :updated_by_id,
        deleter_column: :deleted_by_id
      }
      allow(model_class).to receive(:whodunit_setting) { |key| custom_setting_values[key] }
    end

    it "uses custom column names in associations" do
      expect(user_class).to receive(:has_many).with(
        :created_posts,
        class_name: "Post",
        dependent: :nullify,
        foreign_key: :created_by_id
      )
      expect(user_class).to receive(:has_many).with(
        :updated_posts,
        class_name: "Post",
        dependent: :nullify,
        foreign_key: :updated_by_id
      )
      expect(user_class).to receive(:has_many).with(
        :deleted_posts,
        class_name: "Post",
        dependent: :nullify,
        foreign_key: :deleted_by_id
      )
      described_class.setup_reverse_associations_for_model(model_class)
    end
  end
end
