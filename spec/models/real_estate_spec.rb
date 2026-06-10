require "rails_helper"

RSpec.describe RealEstate, type: :model do
  it "has a valid factory" do
    expect(build(:real_estate)).to be_valid
  end

  it "only allows known statuses" do
    expect(build(:real_estate, status: "bogus")).not_to be_valid
  end

  it "derives map_url from coords (never stored)" do
    re = build(:real_estate, latitude: 10.786219, longitude: 106.65734)
    expect(re.map_url).to eq("https://www.google.com/maps?q=10.786219,106.65734")
    expect(re).not_to respond_to(:map_url=)
  end

  it "returns nil map_url without coords" do
    expect(build(:real_estate, latitude: nil, longitude: nil).map_url).to be_nil
  end

  it "exposes the canonical province via crawl_province, separate from the raw string" do
    province = create(:province, name: "Hồ Chí Minh")
    re = create(:real_estate, crawl_province: province, province: "Tp Hồ Chí Minh")
    expect(re.crawl_province).to eq(province)
    expect(re.province).to eq("Tp Hồ Chí Minh")
  end
end
