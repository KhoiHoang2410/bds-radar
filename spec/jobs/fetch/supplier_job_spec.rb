require "rails_helper"

RSpec.describe Fetch::SupplierJob do
  let(:province) { create(:province, name: "Hồ Chí Minh") }
  let(:ads) { nhatot_ads }

  def run
    described_class.new.perform("nhatot", province.id)
  end

  describe "fetch → store" do
    before { stub_nhatot(region_v2: 13000, ads: ads) }

    it "upserts one active source per ad, stamped with province_id + last_seen_at" do
      run

      expect(RealEstateSource.count).to eq(3)
      src = RealEstateSource.find_by(external_id: ads.first["list_id"].to_s)
      expect(src).to have_attributes(supplier: "nhatot", status: "active", province_id: province.id)
      expect(src.area).to eq(ads.first["size"].round(2).to_d) # m² from `size`
      expect(src.last_seen_at).to be_present
      expect(src.raw_data["list_id"]).to eq(ads.first["list_id"])
    end

    it "is idempotent on (supplier, external_id) — re-fetch updates, never duplicates" do
      run
      run

      expect(RealEstateSource.count).to eq(3)
      expect(RealEstateSource.where(external_id: ads.first["list_id"].to_s).count).to eq(1)
    end
  end

  describe "mark-and-sweep" do
    it "marks a vanished listing inactive while keeping re-seen ones active" do
      stub_nhatot(region_v2: 13000, ads: ads)
      run
      vanished_id = ads.first["list_id"].to_s

      WebMock.reset!
      stub_nhatot(region_v2: 13000, ads: ads.drop(1)) # first ad gone from the feed
      run

      expect(RealEstateSource.find_by(external_id: vanished_id).status).to eq("inactive")
      ads.drop(1).each do |ad|
        expect(RealEstateSource.find_by(external_id: ad["list_id"].to_s).status).to eq("active")
      end
    end
  end

  describe "fetch-then-store crash safety" do
    it "writes nothing and leaves prior status untouched when the fetch fails" do
      stub_nhatot(region_v2: 13000, ads: ads)
      run
      expect(RealEstateSource.active.count).to eq(3)

      WebMock.reset!
      stub_request(:get, /gateway\.chotot\.com/).to_return(status: 500, body: "")

      expect { run }.to raise_error(Suppliers::Base::FetchError)
      expect(RealEstateSource.active.count).to eq(3) # no dark window
    end
  end
end
