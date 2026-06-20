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

  describe "#price_per_m2" do
    it "computes price / area (VND per m²)" do
      re = build(:real_estate, price: 5_000_000_000, area: 50.0)
      expect(re.price_per_m2).to eq(100_000_000)
    end

    it "returns nil when area is blank" do
      expect(build(:real_estate, area: nil).price_per_m2).to be_nil
    end

    it "returns nil when area is zero" do
      expect(build(:real_estate, area: 0).price_per_m2).to be_nil
    end

    it "returns nil when price is blank" do
      expect(build(:real_estate, price: nil).price_per_m2).to be_nil
    end
  end

  it "exposes the canonical province via crawl_province, separate from the raw string" do
    province = create(:province, name: "Hồ Chí Minh")
    re = create(:real_estate, crawl_province: province, province: "Tp Hồ Chí Minh")
    expect(re.crawl_province).to eq(province)
    expect(re.province).to eq("Tp Hồ Chí Minh")
  end
end
