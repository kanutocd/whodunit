# frozen_string_literal: true

RSpec.describe Whodunit::SoftDeleteDetector do
  describe ".enabled_for?" do
    context "when model has gem-based soft delete" do
      it "detects Discard module" do
        model = double(respond_to?: true, included_modules: [double(to_s: "Discard::Model")])
        expect(described_class.enabled_for?(model)).to be true
      end

      it "detects Paranoia methods" do
        model = double(respond_to?: true, included_modules: [])
        allow(model).to receive(:respond_to?).with(:paranoid?).and_return(true)
        expect(described_class.enabled_for?(model)).to be true
      end

      it "detects ActsAsParanoid" do
        model = double(respond_to?: true, included_modules: [])
        allow(model).to receive(:respond_to?).with(:paranoid?).and_return(false)
        allow(model).to receive(:respond_to?).with(:acts_as_paranoid).and_return(true)
        expect(described_class.enabled_for?(model)).to be true
      end
    end

    context "when model has column-based soft delete" do
      it "detects deleted_at column" do
        column = double(name: "deleted_at", type: :datetime)
        model = double(included_modules: [],
                       columns: [column],
                       ancestors: [])
        # Set up specific respond_to? behaviors - order matters!
        allow(model).to receive(:respond_to?) do |method|
          method == :columns
        end

        expect(described_class.enabled_for?(model)).to be true
      end

      it "detects discarded_at column" do
        column = double(name: "discarded_at", type: :timestamp)
        model = double(included_modules: [],
                       columns: [column],
                       ancestors: [])
        # Set up specific respond_to? behaviors
        allow(model).to receive(:respond_to?) do |method|
          method == :columns
        end

        expect(described_class.enabled_for?(model)).to be true
      end

      it "ignores non-timestamp columns with soft delete names" do
        column = double(name: "deleted_at", type: :string)
        model = double(included_modules: [],
                       columns: [column],
                       ancestors: [])
        # Set up specific respond_to? behaviors
        allow(model).to receive(:respond_to?) do |method|
          method == :columns
        end

        expect(described_class.enabled_for?(model)).to be false
      end
    end

    context "when model has method-based soft delete" do
      it "detects deleted_at method" do
        model = double(respond_to?: true,
                       included_modules: [],
                       columns: [],
                       ancestors: [])
        allow(model).to receive(:respond_to?).with(:paranoid?).and_return(false)
        allow(model).to receive(:respond_to?).with(:acts_as_paranoid).and_return(false)
        allow(model).to receive(:respond_to?).with(:deleted_at).and_return(true)

        expect(described_class.enabled_for?(model)).to be true
      end

      it "detects discarded_at method" do
        model = double(respond_to?: true,
                       included_modules: [],
                       columns: [],
                       ancestors: [])
        allow(model).to receive(:respond_to?).with(:paranoid?).and_return(false)
        allow(model).to receive(:respond_to?).with(:acts_as_paranoid).and_return(false)
        allow(model).to receive(:respond_to?).with(:deleted_at).and_return(false)
        allow(model).to receive(:respond_to?).with(:discarded_at).and_return(true)

        expect(described_class.enabled_for?(model)).to be true
      end
    end

    context "when model has no soft delete" do
      it "returns false" do
        model = double(respond_to?: true,
                       included_modules: [],
                       columns: [double(name: "created_at", type: :datetime)],
                       ancestors: [])
        allow(model).to receive(:respond_to?).and_return(false)

        expect(described_class.enabled_for?(model)).to be false
      end
    end

    context "when model doesn't respond to columns" do
      it "returns false" do
        model = double(respond_to?: false)
        expect(described_class.enabled_for?(model)).to be false
      end
    end
  end
end
