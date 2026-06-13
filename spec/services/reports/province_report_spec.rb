require "rails_helper"

RSpec.describe Reports::ProvinceReport do
  let(:hcm) { create(:province, name: "Hồ Chí Minh") }
  let(:other) { create(:province, name: "Hà Nội") }

  def report
    described_class.call(hcm)
  end

  it "counts only active rows of the requested province" do
    create(:real_estate, crawl_province: hcm)
    create(:real_estate, :inactive, crawl_province: hcm)
    create(:real_estate, crawl_province: other)

    expect(report[:total_count]).to eq(1)
  end

  it "summarizes count / average price / average area per type" do
    create(:real_estate, crawl_province: hcm, type: "condo", price: 4_000_000_000, area: 50.0)
    create(:real_estate, crawl_province: hcm, type: "condo", price: 6_000_000_000, area: 70.0)
    create(:real_estate, crawl_province: hcm, type: "land", price: 9_000_000_000, area: 100.0)

    condo = report[:by_type].find { |r| r[:type] == "condo" }
    expect(condo).to include(count: 2, avg_price: 5_000_000_000.0, avg_area: 60.0)
  end

  it "counts listings by bedroom count (across types), excluding rows without bedrooms" do
    create(:real_estate, crawl_province: hcm, type: "condo", bedrooms: 2, price: 4_000_000_000)
    create(:real_estate, crawl_province: hcm, type: "house", bedrooms: 2, price: 6_000_000_000)
    create(:real_estate, crawl_province: hcm, type: "house", bedrooms: 3, price: 9_000_000_000)
    create(:real_estate, crawl_province: hcm, type: "land", bedrooms: nil, price: 5_000_000_000)

    by_bedrooms = report[:by_bedrooms]
    expect(by_bedrooms.map { |r| r[:bedrooms] }).to eq([ 2, 3 ])
    two = by_bedrooms.find { |r| r[:bedrooms] == 2 }
    expect(two).to include(count: 2, avg_price: 5_000_000_000.0)
  end

  it "computes condo average price per bedroom, grouped by bedroom count" do
    create(:real_estate, crawl_province: hcm, type: "condo", bedrooms: 2, price: 4_000_000_000)
    create(:real_estate, crawl_province: hcm, type: "condo", bedrooms: 2, price: 6_000_000_000)
    create(:real_estate, crawl_province: hcm, type: "condo", bedrooms: 3, price: 9_000_000_000)

    rows = report[:price_per_bedroom][:condo]
    two = rows.find { |r| r[:bedrooms] == 2 }
    expect(two).to include(count: 2, avg_price: 5_000_000_000.0, avg_price_per_bedroom: 2_500_000_000.0)
  end

  it "analyses land by ward, each ward broken into area buckets (not by bedroom)" do
    create(:real_estate, crawl_province: hcm, type: "land", ward: "Phường 1", price: 1_000_000_000, area: 25.0)   # P1 < 30
    create(:real_estate, crawl_province: hcm, type: "land", ward: "Phường 1", price: 2_000_000_000, area: 40.0)   # P1 30–50
    create(:real_estate, crawl_province: hcm, type: "land", ward: "Phường 1", price: 4_000_000_000, area: 40.0)   # P1 30–50
    create(:real_estate, crawl_province: hcm, type: "land", ward: "Phường 2", price: 9_000_000_000, area: 200.0)  # P2 ≥ 150
    create(:real_estate, crawl_province: hcm, type: "condo", bedrooms: 2, ward: "Phường 1", price: 5_000_000_000, area: 40.0) # not land

    wards = report[:land_by_ward_area]

    # land has no bedroom-based analysis anymore
    expect(report[:price_per_bedroom]).not_to have_key(:land)

    # wards ordered by listing count desc: Phường 1 (3) before Phường 2 (1)
    expect(wards.map { |w| w[:ward] }).to eq([ "Phường 1", "Phường 2" ])

    p1 = wards.first
    expect(p1[:count]).to eq(3)
    buckets = p1[:buckets].to_h { |b| [ b[:label], b ] }
    expect(buckets["< 30 m²"][:count]).to eq(1)
    mid = buckets["30 – 50 m²"]
    expect(mid[:count]).to eq(2)
    expect(mid[:avg_price]).to eq(3_000_000_000.0)        # (2tỷ + 4tỷ) / 2
    expect(mid[:avg_price_per_m2]).to eq(75_000_000.0)    # (50M + 100M) / 2 per m²
    expect(buckets["50 – 70 m²"][:count]).to eq(0)
    expect(buckets["50 – 70 m²"][:avg_price]).to be_nil

    expect(wards.last[:buckets].find { |b| b[:label] == "≥ 150 m²" }[:count]).to eq(1)
  end

  it "returns no ward rows when the province has no land" do
    create(:real_estate, crawl_province: hcm, type: "condo", bedrooms: 2, price: 5_000_000_000, area: 40.0)

    expect(report[:land_by_ward_area]).to be_empty
  end

  it "buckets listings into price ranges" do
    create(:real_estate, crawl_province: hcm, price: 800_000_000)
    create(:real_estate, crawl_province: hcm, price: 2_000_000_000)
    create(:real_estate, crawl_province: hcm, price: 25_000_000_000)

    dist = report[:price_distribution].to_h { |row| [ row[:label], row[:count] ] }
    expect(dist["< 1 tỷ"]).to eq(1)
    expect(dist["1 – 3 tỷ"]).to eq(1)
    expect(dist["≥ 20 tỷ"]).to eq(1)
    expect(dist["5 – 10 tỷ"]).to eq(0)
  end
end
