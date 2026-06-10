require "rails_helper"

RSpec.describe Suppliers::VnPrice do
  describe ".parse" do
    {
      "8 tỷ 250 triệu" => 8_250_000_000,
      "6 tỷ 750 triệu" => 6_750_000_000,
      "2 tỷ" => 2_000_000_000,
      "950 triệu" => 950_000_000,
      "1,5 tỷ" => 1_500_000_000,
      "8,25 tỷ" => 8_250_000_000
    }.each do |text, expected|
      it "parses #{text.inspect} → #{expected}" do
        expect(described_class.parse(text)).to eq(expected)
      end
    end

    it "returns nil for non-price text" do
      expect(described_class.parse("Thỏa thuận")).to be_nil
      expect(described_class.parse("")).to be_nil
      expect(described_class.parse(nil)).to be_nil
    end
  end
end
