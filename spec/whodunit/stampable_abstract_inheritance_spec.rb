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
