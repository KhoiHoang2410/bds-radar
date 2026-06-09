require "rails_helper"

RSpec.describe WardCity, type: :model do
  it "has a valid factory" do
    expect(build(:ward_city)).to be_valid
  end

  it "requires ward and province" do
    expect(build(:ward_city, ward: nil)).not_to be_valid
    expect(build(:ward_city, province: nil)).not_to be_valid
  end

  it "is unique on (ward, province) but allows the same ward in another province" do
    create(:ward_city, ward: "Phường 1", province: "Hồ Chí Minh")
    expect(build(:ward_city, ward: "Phường 1", province: "Hồ Chí Minh")).not_to be_valid
    expect(build(:ward_city, ward: "Phường 1", province: "Hà Nội")).to be_valid
  end

  it "rejects a ward_alternative that collides with another ward in the same province" do
    create(:ward_city, ward: "Phường Bến Nghé", province: "Hồ Chí Minh", ward_alternatives: [ "Ben Nghe" ])
    clashing = build(:ward_city, ward: "Phường Khác", province: "Hồ Chí Minh", ward_alternatives: [ "Ben Nghe" ])
    expect(clashing).not_to be_valid
    expect(clashing.errors[:ward_alternatives]).to be_present
  end
end
