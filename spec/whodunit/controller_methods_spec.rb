# frozen_string_literal: true

RSpec.describe Whodunit::ControllerMethods do
  let(:controller_class) do
    Class.new do
      include Whodunit::ControllerMethods

      attr_accessor :current_user

      def initialize
        @current_user = nil
      end

      # Mock controller methods
      def respond_to?(method, include_private = false)
        [:current_user].include?(method) || super
      end
    end
  end

  let(:controller) { controller_class.new }
  let(:user) { double(id: 123) }

  before do
    Whodunit::Current.reset
  end

  describe "#set_whodunit_user" do
    it "sets user when current_user is available" do
      controller.current_user = user
      controller.set_whodunit_user

      expect(Whodunit::Current.user).to eq(123)
    end

    it "accepts user parameter" do
      other_user = double(id: 456)
      controller.set_whodunit_user(other_user)

      expect(Whodunit::Current.user).to eq(456)
    end

    it "does nothing when no user available" do
      controller.set_whodunit_user

      expect(Whodunit::Current.user).to be_nil
    end
  end

  describe "#reset_whodunit_user" do
    it "resets the current user context" do
      Whodunit::Current.user = 123
      controller.reset_whodunit_user

      expect(Whodunit::Current.user).to be_nil
    end
  end

  describe "#current_whodunit_user" do
    it "returns current_user when available" do
      controller.current_user = user

      expect(controller.current_whodunit_user).to eq(user)
    end

    it "returns nil when current_user is nil" do
      controller.current_user = nil

      expect(controller.current_whodunit_user).to be_nil
    end

    it "tries alternative user methods when current_user not available" do
      test_user = double(id: 789)
      
      alternative_controller = Class.new do
        include Whodunit::ControllerMethods

        def initialize(user)
          @test_user = user
        end

        def current_account
          @test_user
        end

        def respond_to?(method, include_private = false)
          [:current_account].include?(method) || super
        end
      end.new(test_user)

      expect(alternative_controller.current_whodunit_user.id).to eq(789)
    end

    it "returns nil when no user methods are available" do
      empty_controller = Class.new do
        include Whodunit::ControllerMethods
      end.new

      expect(empty_controller.current_whodunit_user).to be_nil
    end

    it "returns @current_user when available" do
      instance_var_controller = Class.new do
        include Whodunit::ControllerMethods

        def initialize(user)
          @current_user = user
        end
      end.new(user)

      expect(instance_var_controller.current_whodunit_user).to eq(user)
    end
  end

  describe "#whodunit_user_available?" do
    it "returns true when user is available" do
      controller.current_user = user

      expect(controller.whodunit_user_available?).to be true
    end

    it "returns false when no user available" do
      controller.current_user = nil

      expect(controller.whodunit_user_available?).to be false
    end

    it "handles case where present? method is not available" do
      user_without_present = double(id: 123)
      allow(user_without_present).to receive(:present?).and_return(true)
      controller.current_user = user_without_present

      expect(controller.whodunit_user_available?).to be true
    end
  end

  describe "#with_whodunit_user" do
    it "temporarily sets user for block execution" do
      original_user = double(id: 111)
      temp_user = double(id: 222)

      Whodunit::Current.user = original_user

      result = controller.with_whodunit_user(temp_user) do
        expect(Whodunit::Current.user).to eq(222)
        "block_executed"
      end

      expect(result).to eq("block_executed")
      expect(Whodunit::Current.user).to eq(111) # Restored
    end

    it "restores previous user even if block raises error" do
      original_user = double(id: 111)
      temp_user = double(id: 222)

      Whodunit::Current.user = original_user

      expect do
        controller.with_whodunit_user(temp_user) do
          raise "test error"
        end
      end.to raise_error("test error")

      expect(Whodunit::Current.user).to eq(111) # Still restored
    end
  end

  describe "#without_whodunit_user" do
    it "temporarily removes user for block execution" do
      original_user = double(id: 111)

      Whodunit::Current.user = original_user

      result = controller.without_whodunit_user do
        expect(Whodunit::Current.user).to be_nil
        "block_executed"
      end

      expect(result).to eq("block_executed")
      expect(Whodunit::Current.user).to eq(111) # Restored
    end
  end

  describe "class methods" do
    let(:controller_with_class_methods) do
      Class.new do
        include Whodunit::ControllerMethods

        # Mock Rails callback methods
        def self.skip_before_action(*args); end
        def self.skip_after_action(*args); end
        def self.before_action(*args); end
        def self.after_action(*args); end
      end
    end

    describe ".skip_whodunit_for" do
      it "skips whodunit callbacks for specified actions" do
        expect(controller_with_class_methods).to receive(:skip_before_action)
          .with(:set_whodunit_user, only: %i[show index])
        expect(controller_with_class_methods).to receive(:skip_after_action)
          .with(:reset_whodunit_user, only: %i[show index])

        controller_with_class_methods.skip_whodunit_for(:show, :index)
      end
    end

    describe ".whodunit_only_for" do
      it "only enables whodunit for specified actions" do
        expect(controller_with_class_methods).to receive(:skip_before_action).with(:set_whodunit_user)
        expect(controller_with_class_methods).to receive(:skip_after_action).with(:reset_whodunit_user)
        expect(controller_with_class_methods).to receive(:before_action)
          .with(:set_whodunit_user, only: %i[create update], if: :whodunit_user_available?)
        expect(controller_with_class_methods).to receive(:after_action)
          .with(:reset_whodunit_user, only: %i[create update])

        controller_with_class_methods.whodunit_only_for(:create, :update)
      end
    end
  end
end
