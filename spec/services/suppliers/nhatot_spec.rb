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

    it "promotes rooms/toilets/subject and parses list_time (epoch ms) into posted_at" do
      expect(listing.bedrooms).to eq(raw["rooms"])
      expect(listing.bathrooms).to eq(raw["toilets"])
      expect(listing.title).to eq(raw["subject"])
      expect(listing.posted_at).to eq(Time.zone.at(raw["list_time"] / 1000))
    end

    it "leaves the detail columns nil when the raw ad omits them" do
      sparse = supplier.normalize(raw.except("rooms", "toilets", "list_time", "subject"))
      expect([ sparse.bedrooms, sparse.bathrooms, sparse.posted_at, sparse.title ]).to all(be_nil)
    end

    it "extracts the condo project name + id from a real condo ad" do
      condo = supplier.normalize(nhatot_ads("ad_listing_condo").first)
      expect(condo.type).to eq("condo")
      expect(condo.project_name).to eq("Khu đô thị mới Vĩnh Hòa")
      expect(condo.project_external_id).to eq("1614500601")
    end

    it "leaves the project columns nil when the ad has no project (blank string ⇒ nil)" do
      expect(raw["pty_project_name"]).to eq("") # the house fixtures carry an empty string
      expect(listing.project_name).to be_nil
      expect(listing.project_external_id).to be_nil
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
