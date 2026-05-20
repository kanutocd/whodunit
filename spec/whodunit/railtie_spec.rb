# frozen_string_literal: true

require "spec_helper"

RSpec.describe Whodunit::Railtie do
  # The Railtie source uses a runtime constant guard:
  #
  #   class Railtie < (defined?(Rails::Railtie) ? Rails::Railtie : Object)
  #
  # In our spec environment Rails is not loaded, so the class safely inherits
  # from Object – the initializer blocks inside `if defined?(Rails::Railtie)`
  # are skipped entirely.  We verify this safe-load behaviour without mocking
  # any Rails or Railtie internals.

  it "is a Class" do
    expect(described_class).to be_a(Class)
  end

  it "can be instantiated without raising" do
    expect { described_class.new }.not_to raise_error
  end

  context "when Rails is not loaded in the test environment" do
    it "inherits from Object (safe no-op fallback)" do
      expect(described_class.superclass).to eq(Object)
    end

    it "does not define Rails-specific initializer callbacks on the class" do
      # Rails::Railtie initializers are registered via DSL methods that are
      # absent on a plain Object subclass.
      expect(described_class).not_to respond_to(:initializer)
    end

    it "does not raise when the file is re-required" do
      expect { require "whodunit/railtie" }.not_to raise_error
    end
  end

  context "ActiveRecord::Migration integration (via bottom-of-file hook)" do
    # migration_helpers.rb appends:
    #   ActiveRecord::Migration.include(Whodunit::MigrationHelpers) if defined?(ActiveRecord::Migration)
    # Since we load activerecord as a runtime dep, this should already be applied.
    it "extends ActiveRecord::Migration with MigrationHelpers" do
      expect(ActiveRecord::Migration.ancestors).to include(Whodunit::MigrationHelpers)
    end
  end
end
