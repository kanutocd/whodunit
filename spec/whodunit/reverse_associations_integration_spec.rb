# frozen_string_literal: true

RSpec.describe "Whodunit Reverse Associations Integration" do
  # Helper that builds a real AR subclass so Stampable's `included` block
  # runs through genuine ActiveRecord infrastructure (callbacks, column_names).
  def ar_model_class(name_str = nil, &block)
    Class.new(ActiveRecord::Base) do
      self.table_name = "whodunit_records"
      define_singleton_method(:name) { name_str } if name_str
      include Whodunit::Stampable

      # block runs after include so Stampable class methods are available
      class_eval(&block) if block
    end
  end

  before do
    Whodunit.auto_setup_reverse_associations = true
    Whodunit.reverse_association_prefix      = ""
    Whodunit.reverse_association_suffix      = ""
    Whodunit.registered_models.clear
  end

  # model registration

  describe "reverse association registration and setup" do
    it "tracks registered models" do
      expect(Whodunit.registered_models).to be_empty
      model = ar_model_class("TestModel")
      expect(Whodunit.registered_models).to include(model)
    end

    it "does not register models when reverse associations are disabled globally" do
      Whodunit.auto_setup_reverse_associations = false
      model = ar_model_class("TestModel2")
      expect(Whodunit.registered_models).not_to include(model)
    end

    it "does not register models when reverse associations are disabled per-model" do
      model = ar_model_class("TestModel3") { disable_whodunit_reverse_associations! }
      expect(Whodunit.registered_models).not_to include(model)
    end
  end

  # association name generation

  describe "reverse association name generation" do
    it "generates correct default names" do
      expect(Whodunit.generate_reverse_association_name("created",  "posts")).to    eq("created_posts")
      expect(Whodunit.generate_reverse_association_name("updated",  "comments")).to eq("updated_comments")
      expect(Whodunit.generate_reverse_association_name("deleted",  "documents")).to eq("deleted_documents")
    end

    it "uses configured prefix and suffix" do
      Whodunit.reverse_association_prefix = "whodunit_"
      Whodunit.reverse_association_suffix = "_tracked"
      expect(Whodunit.generate_reverse_association_name("created", "posts")).to eq("whodunit_created_posts_tracked")
    end
  end

  # configuration

  describe "configuration" do
    it "has correct default values" do
      expect(Whodunit.auto_setup_reverse_associations).to be true
      expect(Whodunit.reverse_association_prefix).to eq("")
      expect(Whodunit.reverse_association_suffix).to eq("")
    end

    it "allows configuring all reverse association settings via .configure" do
      Whodunit.configure do |config|
        config.auto_setup_reverse_associations = false
        config.reverse_association_prefix      = "prefix_"
        config.reverse_association_suffix      = "_suffix"
      end

      expect(Whodunit.auto_setup_reverse_associations).to be false
      expect(Whodunit.reverse_association_prefix).to eq("prefix_")
      expect(Whodunit.reverse_association_suffix).to eq("_suffix")
    end
  end

  # model-level reverse association control

  describe "model-level reverse association control" do
    let(:test_model) { ar_model_class("TestModel4") }

    it "has reverse associations enabled by default" do
      expect(test_model.whodunit_reverse_associations_enabled?).to be true
    end

    it "can be disabled" do
      test_model.disable_whodunit_reverse_associations!
      expect(test_model.whodunit_reverse_associations_enabled?).to be false
    end

    it "does not call setup when disabled" do
      test_model.disable_whodunit_reverse_associations!
      expect(Whodunit).not_to receive(:setup_reverse_associations_for_model)
      test_model.setup_whodunit_reverse_associations!
    end

    it "calls setup when manually triggered while enabled" do
      test_model.instance_variable_set(:@whodunit_reverse_associations_disabled, false)
      expect(Whodunit).to receive(:setup_reverse_associations_for_model).with(test_model)
      test_model.setup_whodunit_reverse_associations!
    end
  end
end
