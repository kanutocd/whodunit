# frozen_string_literal: true

RSpec.describe "Whodunit Reverse Associations Integration" do
  before do
    # Reset configuration to defaults
    Whodunit.auto_setup_reverse_associations = true
    Whodunit.reverse_association_prefix = ""
    Whodunit.reverse_association_suffix = ""
    Whodunit.registered_models.clear
  end

  describe "reverse association registration and setup" do
    it "tracks registered models" do
      expect(Whodunit.registered_models).to be_empty

      # Create a new model class that includes Stampable
      test_model = Class.new do
        def self.before_create(*args); end
        def self.before_update(*args); end
        def self.before_destroy(*args); end
        def self.belongs_to(*args); end

        def self.column_names
          %w[id creator_id updater_id deleter_id]
        end

        def self.name
          "TestModel"
        end
        include Whodunit::Stampable
      end

      expect(Whodunit.registered_models).to include(test_model)
    end

    it "does not register models when reverse associations are disabled globally" do
      Whodunit.auto_setup_reverse_associations = false
      initial_count = Whodunit.registered_models.size

      test_model = Class.new do
        def self.before_create(*args); end
        def self.before_update(*args); end
        def self.before_destroy(*args); end
        def self.belongs_to(*args); end

        def self.column_names
          %w[id creator_id updater_id deleter_id]
        end

        def self.name
          "TestModel2"
        end
        include Whodunit::Stampable
      end

      expect(Whodunit.registered_models.size).to eq(initial_count)
      expect(Whodunit.registered_models).not_to include(test_model)
    end

    it "does not register models when reverse associations are disabled per model" do
      initial_count = Whodunit.registered_models.size

      test_model = Class.new do
        def self.before_create(*args); end
        def self.before_update(*args); end
        def self.before_destroy(*args); end
        def self.belongs_to(*args); end

        def self.column_names
          %w[id creator_id updater_id deleter_id]
        end

        def self.name
          "TestModel3"
        end
        include Whodunit::Stampable
        disable_whodunit_reverse_associations!
      end

      expect(Whodunit.registered_models.size).to eq(initial_count)
      expect(Whodunit.registered_models).not_to include(test_model)
    end
  end

  describe "reverse association name generation" do
    it "generates correct association names" do
      expect(Whodunit.generate_reverse_association_name("created", "posts")).to eq("created_posts")
      expect(Whodunit.generate_reverse_association_name("updated", "comments")).to eq("updated_comments")
      expect(Whodunit.generate_reverse_association_name("deleted", "documents")).to eq("deleted_documents")
    end

    it "uses prefix and suffix when configured" do
      Whodunit.reverse_association_prefix = "whodunit_"
      Whodunit.reverse_association_suffix = "_tracked"

      expect(Whodunit.generate_reverse_association_name("created", "posts")).to eq("whodunit_created_posts_tracked")

      # Reset
      Whodunit.reverse_association_prefix = ""
      Whodunit.reverse_association_suffix = ""
    end
  end

  describe "configuration" do
    it "has correct default values for reverse association settings" do
      expect(Whodunit.auto_setup_reverse_associations).to be(true)
      expect(Whodunit.reverse_association_prefix).to eq("")
      expect(Whodunit.reverse_association_suffix).to eq("")
    end

    it "allows configuration of reverse association settings" do
      Whodunit.configure do |config|
        config.auto_setup_reverse_associations = false
        config.reverse_association_prefix = "prefix_"
        config.reverse_association_suffix = "_suffix"
      end

      expect(Whodunit.auto_setup_reverse_associations).to be(false)
      expect(Whodunit.reverse_association_prefix).to eq("prefix_")
      expect(Whodunit.reverse_association_suffix).to eq("_suffix")

      # Reset for other tests
      Whodunit.auto_setup_reverse_associations = true
      Whodunit.reverse_association_prefix = ""
      Whodunit.reverse_association_suffix = ""
    end
  end

  describe "model-level reverse association control" do
    let(:test_model) do
      Class.new do
        def self.before_create(*args); end
        def self.before_update(*args); end
        def self.before_destroy(*args); end
        def self.belongs_to(*args); end

        def self.column_names
          %w[id creator_id updater_id deleter_id]
        end

        def self.name
          "TestModel4"
        end
        include Whodunit::Stampable
      end
    end

    it "has reverse associations enabled by default" do
      expect(test_model.whodunit_reverse_associations_enabled?).to be(true)
    end

    it "can disable reverse associations" do
      test_model.disable_whodunit_reverse_associations!
      expect(test_model.whodunit_reverse_associations_enabled?).to be(false)
    end

    it "does not set up reverse associations when disabled" do
      # First disable reverse associations
      test_model.disable_whodunit_reverse_associations!
      expect(test_model.whodunit_reverse_associations_enabled?).to be(false)

      # When disabled, manual setup should not call the setup method
      expect(Whodunit).not_to receive(:setup_reverse_associations_for_model)
      test_model.setup_whodunit_reverse_associations!
    end

    it "can manually set up reverse associations when enabled" do
      # Ensure associations are enabled
      test_model.instance_variable_set(:@whodunit_reverse_associations_disabled, false)
      expect(test_model.whodunit_reverse_associations_enabled?).to be(true)

      expect(Whodunit).to receive(:setup_reverse_associations_for_model).with(test_model)
      test_model.setup_whodunit_reverse_associations!
    end
  end
end
