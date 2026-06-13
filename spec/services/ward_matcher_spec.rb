require "rails_helper"

RSpec.describe WardMatcher do
  let(:province) { create(:province, name: "Hồ Chí Minh") }

  describe "resolution chain" do
    it "matches exactly on (ward, province_id)" do
      w = create(:ward, ward: "Phường Bến Nghé", province: province)
      expect(described_class.call(ward: "Phường Bến Nghé", province_id: province.id)).to eq(w.id)
    end

    it "matches via a ward alternative" do
      w = create(:ward, ward: "Phường Bến Nghé", province: province, ward_alternatives: [ "Ben Nghe" ])
      expect(described_class.call(ward: "Ben Nghe", province_id: province.id)).to eq(w.id)
    end

    it "matches fuzzily, ignoring diacritics/case/spacing" do
      w = create(:ward, ward: "Phường Bến Nghé", province: province)
      expect(described_class.call(ward: "phuong  ben nghe", province_id: province.id)).to eq(w.id)
    end
  end

  describe "best-effort failure modes (return nil, never raise)" do
    it "returns nil when an input ward is ambiguous between equally-close wards" do
      create(:ward, ward: "Phường 1", province: province)
      create(:ward, ward: "Phường 4", province: province)
      # "Phường 7" is edit-distance 1 from BOTH — a numbered-ward tie.
      expect(described_class.call(ward: "Phường 7", province_id: province.id)).to be_nil
    end

    it "returns nil when nothing is close enough" do
      create(:ward, ward: "Phường Bến Nghé", province: province)
      expect(described_class.call(ward: "Xã Hoàn Toàn Khác", province_id: province.id)).to be_nil
    end

    it "returns nil for a province with no wards" do
      create(:ward, ward: "Phường Bến Nghé", province: province)
      other = create(:province, name: "Đà Nẵng")
      expect(described_class.call(ward: "Phường Bến Nghé", province_id: other.id)).to be_nil
    end

    it "returns nil for blank input" do
      expect(described_class.call(ward: "", province_id: province.id)).to be_nil
    end
  end
end
