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
end
