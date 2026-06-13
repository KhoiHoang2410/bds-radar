require "rails_helper"

RSpec.describe StringMatcher do
  describe ".receive" do
    it "returns 0 when the needle is an exact (normalized) substring of the haystack" do
      expect(described_class.receive("Bán căn hộ The Origami Quận 9", "The Origami")).to eq(0)
    end

    it "ignores diacritics, case, and spacing on both sides" do
      expect(described_class.receive("can ho the  origami", "Thé Origami")).to eq(0)
    end

    it "returns the edit distance for a near match within the error bound" do
      # one substitution within the matched window
      expect(described_class.receive("khu do thi vinh hoa", "vinh haa")).to eq(1)
    end

    it "returns nil when the needle is too far from any substring" do
      expect(described_class.receive("hoàn toàn khác biệt", "The Origami")).to be_nil
    end

    it "honours an explicit max_error" do
      expect(described_class.receive("aurora riverside", "aurara", max_error: 0)).to be_nil
      expect(described_class.receive("aurora riverside", "aurara", max_error: 1)).to eq(1)
    end

    it "returns nil when the needle is longer than the haystack" do
      expect(described_class.receive("Origami", "The Origami Grand Park")).to be_nil
    end

    it "returns nil for blank input on either side" do
      expect(described_class.receive("", "anything")).to be_nil
      expect(described_class.receive("anything", "  ")).to be_nil
    end

    it "finds the needle regardless of where it sits in the haystack" do
      expect(described_class.receive("bán gấp căn hộ akari city giá tốt", "Akari City")).to eq(0)
    end
  end
end
