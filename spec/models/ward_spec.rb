require "rails_helper"

RSpec.describe Ward, type: :model do
  it "has a valid factory" do
    expect(build(:ward)).to be_valid
  end

  it "requires a ward and a province" do
    expect(build(:ward, ward: nil)).not_to be_valid
    expect(build(:ward, province: nil)).not_to be_valid
  end

  it "is unique on (ward, province_id) but allows the same ward in another province" do
    hcm = create(:province, name: "Hồ Chí Minh")
    hanoi = create(:province, name: "Hà Nội")
    create(:ward, ward: "Phường 1", province: hcm)

    expect(build(:ward, ward: "Phường 1", province: hcm)).not_to be_valid
    expect(build(:ward, ward: "Phường 1", province: hanoi)).to be_valid
  end

  it "rejects a ward_alternative that collides with another ward in the same province" do
    hcm = create(:province, name: "Hồ Chí Minh")
    create(:ward, ward: "Phường Bến Nghé", province: hcm, ward_alternatives: [ "Ben Nghe" ])
    clashing = build(:ward, ward: "Phường Khác", province: hcm, ward_alternatives: [ "Ben Nghe" ])

    expect(clashing).not_to be_valid
    expect(clashing.errors[:ward_alternatives]).to be_present
  end

  describe ".match (resolution via StringMatcher)" do
    let(:province) { create(:province, name: "Hồ Chí Minh") }

    it "matches exactly on (ward, province_id)" do
      w = create(:ward, ward: "Phường Bến Nghé", province: province)
      expect(Ward.match(ward: "Phường Bến Nghé", province_id: province.id)).to eq(w.id)
    end

    it "matches via a ward alternative" do
      w = create(:ward, ward: "Phường Bến Nghé", province: province, ward_alternatives: [ "Ben Nghe" ])
      expect(Ward.match(ward: "Ben Nghe", province_id: province.id)).to eq(w.id)
    end

    it "matches fuzzily, ignoring diacritics/case/spacing" do
      w = create(:ward, ward: "Phường Bến Nghé", province: province)
      expect(Ward.match(ward: "phuong  ben nghe", province_id: province.id)).to eq(w.id)
    end

    it "returns nil when an input ward is ambiguous between equally-close wards" do
      create(:ward, ward: "Phường 1", province: province)
      create(:ward, ward: "Phường 4", province: province)
      expect(Ward.match(ward: "Phường 7", province_id: province.id)).to be_nil
    end

    it "returns nil when nothing is close enough" do
      create(:ward, ward: "Phường Bến Nghé", province: province)
      expect(Ward.match(ward: "Xã Hoàn Toàn Khác", province_id: province.id)).to be_nil
    end

    it "returns nil for a province with no wards" do
      create(:ward, ward: "Phường Bến Nghé", province: province)
      other = create(:province, name: "Đà Nẵng")
      expect(Ward.match(ward: "Phường Bến Nghé", province_id: other.id)).to be_nil
    end

    it "returns nil for blank input" do
      expect(Ward.match(ward: "", province_id: province.id)).to be_nil
    end
  end
end
