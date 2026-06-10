require "rails_helper"

# End-to-end against recorded fixtures (spec §7): crawl nhatot → normalize → query.
RSpec.describe "Fetch → Normalize → Query pipeline", type: :request do
  it "crawls nhatot, normalizes, and serves the listings through the query API" do
    hcm = create(:province, name: "Hồ Chí Minh", schedule_fetch: true)
    stub_nhatot(region_v2: 13000, ads: nhatot_ads)

    Fetch::SupplierJob.new.perform("nhatot", hcm.id)
    Normalize::ProvinceJob.new.perform(hcm.id)

    get "/real_estates", params: { province_id: hcm.id }

    body = response.parsed_body.fetch("real_estates")
    expect(body.size).to eq(nhatot_ads.size)
    expect(body).to all(include("province_id" => hcm.id, "status" => "active"))

    # A known fixture listing flows through end-to-end, m² from `size`, derived map_url.
    ad = nhatot_ads.first
    listing = body.find { |r| r["source_urls"].first.include?(ad["list_id"].to_s) }
    expect(listing).to include(
      "type" => "house",
      "price" => ad["price"],
      "area" => ad["size"].round(2)
    )
    expect(listing["map_url"]).to eq("https://www.google.com/maps?q=#{ad['latitude']},#{ad['longitude']}")
  end
end
