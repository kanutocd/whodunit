# frozen_string_literal: true

RSpec.describe Whodunit::Current do
  describe ".user=" do
    it "stores user object's id" do
      user = double(id: 123)
      described_class.user = user
      expect(described_class.user).to eq(123)
    end

    it "stores user id directly" do
      described_class.user = 456
      expect(described_class.user).to eq(456)
    end

    it "handles nil user" do
      described_class.user = nil
      expect(described_class.user).to be_nil
    end
  end

  describe ".user_id" do
    it "returns stored user id" do
      described_class.user = 789
      expect(described_class.user_id).to eq(789)
    end

    it "returns nil when no user set" do
      described_class.user = nil
      expect(described_class.user_id).to be_nil
    end
  end

  describe "thread safety" do
    it "isolates user across threads" do
      other_thread_user = nil

      described_class.user = 1
      main_thread_user = described_class.user

      thread = Thread.new do
        described_class.user = 2
        other_thread_user = described_class.user
      end

      thread.join

      expect(main_thread_user).to eq(1)
      expect(other_thread_user).to eq(2)
      expect(described_class.user).to eq(1) # Main thread unchanged
    end
  end
end
