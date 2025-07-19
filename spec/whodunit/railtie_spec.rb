# frozen_string_literal: true

RSpec.describe Whodunit::Railtie do
  describe "railtie class" do
    it "exists and can be instantiated" do
      expect(described_class).to be_a(Class)
      expect { described_class.new }.not_to raise_error
    end

    context "when Rails is available" do
      before do
        # This test would run in a real Rails environment
        skip "Rails not available in test environment"
      end

      it "inherits from Rails::Railtie" do
        expect(described_class).to be < Rails::Railtie
      end

      it "has the correct railtie name" do
        expect(described_class.railtie_name).to eq(:whodunit)
      end
    end

    context "when Rails is not available" do
      it "inherits from Object and doesn't break" do
        # Since we're testing without Rails, it should inherit from Object
        # and not break when loaded
        expect(described_class.superclass).to eq(Object)
      end
    end
  end
end
