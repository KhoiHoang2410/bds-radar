require "rails_helper"

RSpec.describe Suppliers::Nhatot do
  let(:supplier) { described_class.new }
  let(:raw) { nhatot_ads.first }

  describe "#normalize (parser)" do
    subject(:listing) { supplier.normalize(raw) }

    it "reads m² from `size`, NOT `area` (the district-code trap)" do
      expect(raw["area"]).to eq(112)          # district code, not m²
      expect(listing.area).to eq(raw["size"]) # 43.8498 m²
      expect(listing.area).not_to eq(raw["area"])
    end

    it "maps category → canonical type" do
      expect(raw["category"]).to eq(1020)
      expect(listing.type).to eq("house")
    end

    it "carries price, coords, and images" do
      expect(listing.price).to eq(raw["price"])
      expect(listing.latitude).to eq(raw["latitude"])
      expect(listing.longitude).to eq(raw["longitude"])
      expect(listing.image_urls).to eq(raw["images"])
    end

    it "builds the admin path from raw supplier strings and derives source_url from list_id" do
      expect(listing.province).to eq(raw["region_name"])         # raw drift, e.g. "Tp Hồ Chí Minh"
      expect(listing.district_or_city).to eq(raw["area_name"])   # district
      expect(listing.ward).to eq(raw["ward_name"])
      expect(listing.external_id).to eq(raw["list_id"].to_s)
      expect(listing.source_url).to include(raw["list_id"].to_s)
    end

    it "falls back to type=other for an unknown category" do
      expect(supplier.normalize(raw.merge("category" => 9999)).type).to eq("other")
    end
  end

  describe "#each_listing" do
    let(:province) { create(:province, name: "Hồ Chí Minh") }

    it "GETs the gateway for the region and yields each raw ad" do
      stub_nhatot(region_v2: 13000, ads: nhatot_ads)

      yielded = []
      count = supplier.each_listing(province, 0) { |ad| yielded << ad }

      expect(count).to eq(3)
      expect(yielded.map { |a| a["list_id"] }).to eq(nhatot_ads.map { |a| a["list_id"] })
      expect(a_request(:get, /gateway\.chotot\.com/).with(query: hash_including("region_v2" => "13000")))
        .to have_been_made
    end
  end
end
