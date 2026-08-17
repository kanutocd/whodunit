# frozen_string_literal: true

require "spec_helper"

RSpec.describe Whodunit::Stampable do
  before do
    ActiveRecord::Schema.define do
      suppress_messages do
        create_table(:whodunit_test_users, force: true) do |t|
          t.string :name
        end

        create_table(:whodunit_test_posts, force: true) do |t|
          t.string :title
          t.integer :creator_id
          t.integer :updater_id
          t.integer :deleter_id
        end
      end
    end

    stub_const("WhodunitTestUser", Class.new(ActiveRecord::Base))
    WhodunitTestUser.table_name = "whodunit_test_users"

    Whodunit.registered_models.clear if Whodunit.respond_to?(:registered_models)
  end

  after do
    Whodunit::Current.reset
  end

  it "defers association setup and registration from an abstract base to concrete subclasses" do
    stub_const("WhodunitTestApplicationRecord", Class.new(ActiveRecord::Base))
    WhodunitTestApplicationRecord.abstract_class = true
    WhodunitTestApplicationRecord.include described_class

    stub_const("WhodunitTestPost", Class.new(WhodunitTestApplicationRecord))
    WhodunitTestPost.table_name = "whodunit_test_posts"

    WhodunitTestPost.send(:setup_whodunit_associations)
    Whodunit.register_model(WhodunitTestPost)

    expect(WhodunitTestPost.reflect_on_association(:creator)).not_to be_nil
    expect(WhodunitTestPost.reflect_on_association(:updater)).not_to be_nil
    expect(Whodunit.registered_models).to include(WhodunitTestPost)
  end

  it "runs deferred setup from the inherited hook for concrete subclasses" do
    stub_const("WhodunitTestApplicationRecord", Class.new(ActiveRecord::Base))
    WhodunitTestApplicationRecord.abstract_class = true
    WhodunitTestApplicationRecord.include described_class

    stub_const("WhodunitTestPost", Class.new(WhodunitTestApplicationRecord))
    WhodunitTestPost.table_name = "whodunit_test_posts"
    allow(WhodunitTestPost).to receive(:setup_whodunit_associations)

    WhodunitTestApplicationRecord.send(:inherited, WhodunitTestPost)

    expect(WhodunitTestPost).to have_received(:setup_whodunit_associations)
    expect(Whodunit.registered_models).to include(WhodunitTestPost)
  end

  it "preserves existing inherited hooks on the abstract base" do
    inherited_subclasses = []

    stub_const("WhodunitTestApplicationRecord", Class.new(ActiveRecord::Base))
    WhodunitTestApplicationRecord.abstract_class = true

    WhodunitTestApplicationRecord.define_singleton_method(:inherited) do |subclass|
      super(subclass)
      inherited_subclasses << subclass
    end

    WhodunitTestApplicationRecord.include described_class

    stub_const("WhodunitTestPost", Class.new(WhodunitTestApplicationRecord))
    WhodunitTestPost.table_name = "whodunit_test_posts"

    WhodunitTestPost.send(:setup_whodunit_associations)
    Whodunit.register_model(WhodunitTestPost)

    expect(inherited_subclasses).to include(WhodunitTestPost)
    expect(WhodunitTestPost.reflect_on_association(:creator)).not_to be_nil
    expect(Whodunit.registered_models).to include(WhodunitTestPost)
  end

  it "does not register abstract subclasses" do
    stub_const("WhodunitTestApplicationRecord", Class.new(ActiveRecord::Base))
    WhodunitTestApplicationRecord.abstract_class = true
    WhodunitTestApplicationRecord.include described_class

    stub_const("WhodunitTestAbstractRecord", Class.new(WhodunitTestApplicationRecord))
    WhodunitTestAbstractRecord.abstract_class = true

    expect(Whodunit.registered_models).not_to include(WhodunitTestAbstractRecord)
    expect(WhodunitTestAbstractRecord.reflect_on_association(:creator)).to be_nil
  end

  it "does not set up associations for an abstract model" do
    stub_const("WhodunitTestApplicationRecord", Class.new(ActiveRecord::Base))
    WhodunitTestApplicationRecord.abstract_class = true
    WhodunitTestApplicationRecord.include described_class

    WhodunitTestApplicationRecord.send(:setup_whodunit_associations)

    expect(WhodunitTestApplicationRecord.reflect_on_association(:creator)).to be_nil
  end

  it "skips abstract subclasses in the inherited hook" do
    stub_const("WhodunitTestApplicationRecord", Class.new(ActiveRecord::Base))
    WhodunitTestApplicationRecord.abstract_class = true
    WhodunitTestApplicationRecord.include described_class

    stub_const("WhodunitTestAbstractRecord", Class.new(WhodunitTestApplicationRecord))
    WhodunitTestAbstractRecord.abstract_class = true

    WhodunitTestApplicationRecord.send(:inherited, WhodunitTestAbstractRecord)

    expect(Whodunit.registered_models).not_to include(WhodunitTestAbstractRecord)
  end

  it "skips association setup when stamp columns are absent" do
    stub_const("WhodunitTestBareRecord", Class.new(ActiveRecord::Base))
    WhodunitTestBareRecord.table_name = "whodunit_test_users"
    WhodunitTestBareRecord.include described_class
    WhodunitTestBareRecord.send(:setup_whodunit_associations)

    expect(WhodunitTestBareRecord.reflect_on_association(:creator)).to be_nil
  end

  it "skips association setup when the model table does not exist yet" do
    stub_const("WhodunitTestUnmigratedRecord", Class.new(ActiveRecord::Base))
    WhodunitTestUnmigratedRecord.table_name = "table_created_by_a_future_migration"

    expect { WhodunitTestUnmigratedRecord.include described_class }.not_to raise_error
    expect(WhodunitTestUnmigratedRecord.reflect_on_association(:creator)).to be_nil
  end

  it "sets up the deleter association when soft delete is enabled" do
    Whodunit.soft_delete_column = :deleted_at
    stub_const("WhodunitTestDeletableRecord", Class.new(ActiveRecord::Base))
    WhodunitTestDeletableRecord.table_name = "whodunit_test_posts"
    WhodunitTestDeletableRecord.include described_class
    WhodunitTestDeletableRecord.send(:setup_whodunit_associations)

    expect(WhodunitTestDeletableRecord.reflect_on_association(:deleter)).not_to be_nil
  ensure
    Whodunit.soft_delete_column = nil
  end

  it "supports multi-level abstract inheritance before the concrete model is defined" do
    stub_const("WhodunitTestApplicationRecord", Class.new(ActiveRecord::Base))
    WhodunitTestApplicationRecord.abstract_class = true
    WhodunitTestApplicationRecord.include described_class

    stub_const("WhodunitTestTenantRecord", Class.new(WhodunitTestApplicationRecord))
    WhodunitTestTenantRecord.abstract_class = true

    stub_const("WhodunitTestPost", Class.new(WhodunitTestTenantRecord))
    WhodunitTestPost.table_name = "whodunit_test_posts"

    WhodunitTestPost.send(:setup_whodunit_associations)
    Whodunit.register_model(WhodunitTestPost)

    expect(WhodunitTestPost.reflect_on_association(:creator)).not_to be_nil
    expect(WhodunitTestPost.reflect_on_association(:updater)).not_to be_nil
    expect(Whodunit.registered_models).to include(WhodunitTestPost)
  end

  it "sets stamps through inherited callbacks on concrete subclasses" do
    user = WhodunitTestUser.create!(name: "Ken")

    stub_const("WhodunitTestApplicationRecord", Class.new(ActiveRecord::Base))
    WhodunitTestApplicationRecord.abstract_class = true
    WhodunitTestApplicationRecord.include described_class

    stub_const("WhodunitTestPost", Class.new(WhodunitTestApplicationRecord))
    WhodunitTestPost.table_name = "whodunit_test_posts"

    WhodunitTestPost.send(:setup_whodunit_associations)
    Whodunit.register_model(WhodunitTestPost)

    Whodunit::Current.user = user

    record = WhodunitTestPost.create!(title: "first")
    record.update!(title: "second")

    expect(record.reload.creator_id).to eq(user.id)
    expect(record.updater_id).to eq(user.id)
  end
end
