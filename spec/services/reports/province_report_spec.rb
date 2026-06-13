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

  it "reports land price per m² (land has no bedrooms)" do
    create(:real_estate, crawl_province: hcm, type: "land", bedrooms: nil, price: 5_000_000_000, area: 100.0)
    create(:real_estate, crawl_province: hcm, type: "land", bedrooms: nil, price: 9_000_000_000, area: 100.0)

    land = report[:land_price_per_m2]
    expect(land[:count]).to eq(2)
    expect(land[:avg_price_per_m2]).to eq(70_000_000.0) # (50M + 90M) / 2 per m²
    expect(report[:price_per_bedroom][:land]).to be_empty
  end

  it "groups condos by project with 1-/2-bedroom average price, price/m², and count" do
    create(:real_estate, crawl_province: hcm, type: "condo", project_name: "Vinhomes", bedrooms: 1, price: 2_000_000_000, area: 40.0)
    create(:real_estate, crawl_province: hcm, type: "condo", project_name: "Vinhomes", bedrooms: 2, price: 4_000_000_000, area: 50.0)
    create(:real_estate, crawl_province: hcm, type: "condo", project_name: "Vinhomes", bedrooms: 2, price: 6_000_000_000, area: 50.0)
    create(:real_estate, crawl_province: hcm, type: "condo", project_name: "Masteri", bedrooms: 1, price: 3_000_000_000, area: 60.0)
    # excluded: blank project, and non-condo types
    create(:real_estate, crawl_province: hcm, type: "condo", project_name: nil, bedrooms: 2, price: 5_000_000_000)
    create(:real_estate, crawl_province: hcm, type: "house", project_name: "Vinhomes", bedrooms: 2, price: 9_000_000_000)

    projects = report[:condo_by_project]
    expect(projects.map { |r| r[:project_name] }).to eq(%w[Vinhomes Masteri]) # sorted by count desc

    vin = projects.find { |r| r[:project_name] == "Vinhomes" }
    expect(vin[:count]).to eq(3)
    expect(vin[:avg_price_1bed]).to eq(2_000_000_000.0)
    expect(vin[:avg_price_2bed]).to eq(5_000_000_000.0)
    # (50M + 80M + 120M) / 3 per m²
    expect(vin[:avg_price_per_m2]).to be_within(1.0).of(83_333_333.33)
  end

  it "returns an empty condo-by-project list when no condo has a project name" do
    create(:real_estate, crawl_province: hcm, type: "condo", project_name: nil, bedrooms: 2)
    create(:real_estate, crawl_province: hcm, type: "land", project_name: "", bedrooms: nil)

    expect(report[:condo_by_project]).to be_empty
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
