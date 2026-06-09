require "rails_helper"

RSpec.describe WardCityMatcher do
  let(:province) { "Hồ Chí Minh" }

  describe "resolution chain" do
    it "matches exactly on (ward, province)" do
      wc = create(:ward_city, ward: "Phường Bến Nghé", province: province)
      expect(described_class.call(ward: "Phường Bến Nghé", province: province)).to eq(wc.id)
    end

    it "matches via a ward alternative" do
      wc = create(:ward_city, ward: "Phường Bến Nghé", province: province, ward_alternatives: [ "Ben Nghe" ])
      expect(described_class.call(ward: "Ben Nghe", province: province)).to eq(wc.id)
    end

    it "matches fuzzily, ignoring diacritics/case/spacing" do
      wc = create(:ward_city, ward: "Phường Bến Nghé", province: province)
      expect(described_class.call(ward: "phuong  ben nghe", province: province)).to eq(wc.id)
    end

    it "resolves the province via a raw-drift alternative" do
      wc = create(:ward_city, ward: "Phường Bến Nghé", province: province, province_alternatives: [ "Tp Hồ Chí Minh" ])
      expect(described_class.call(ward: "Phường Bến Nghé", province: "Tp Hồ Chí Minh")).to eq(wc.id)
    end
  end

  describe "best-effort failure modes (return nil, never raise)" do
    it "returns nil when an input ward is ambiguous between equally-close wards" do
      create(:ward_city, ward: "Phường 1", province: province)
      create(:ward_city, ward: "Phường 4", province: province)
      # "Phường 7" is edit-distance 1 from BOTH — a numbered-ward tie.
      expect(described_class.call(ward: "Phường 7", province: province)).to be_nil
    end

    it "returns nil when nothing is close enough" do
      create(:ward_city, ward: "Phường Bến Nghé", province: province)
      expect(described_class.call(ward: "Xã Hoàn Toàn Khác", province: province)).to be_nil
    end

    it "returns nil for an unknown province" do
      create(:ward_city, ward: "Phường Bến Nghé", province: province)
      expect(described_class.call(ward: "Phường Bến Nghé", province: "Đà Nẵng")).to be_nil
    end

    it "returns nil for blank input" do
      expect(described_class.call(ward: "", province: province)).to be_nil
    end
  end
end
