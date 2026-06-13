require "rails_helper"

RSpec.describe Reports::ProvinceReportHtml do
  let(:hcm) { create(:province, name: "Hồ Chí Minh") }

  def html
    described_class.call(Reports::ProvinceReport.call(hcm))
  end

  it "renders a full HTML document with the province name and the chart canvases" do
    create(:real_estate, crawl_province: hcm, type: "condo", bedrooms: 2, price: 4_000_000_000, area: 50.0)

    doc = html
    expect(doc).to start_with("<!DOCTYPE html>")
    expect(doc).to include("<title>Report for Hồ Chí Minh</title>")
    expect(doc).to include("Hồ Chí Minh")
    expect(doc).to include("cdn.jsdelivr.net/npm/chart.js")
    %w[byType byBedrooms avgPrice priceDist].each do |canvas|
      expect(doc).to include(%(id="#{canvas}"))
    end
  end

  it "embeds the aggregated figures as JSON for the charts" do
    create(:real_estate, crawl_province: hcm, type: "condo", bedrooms: 2, price: 4_000_000_000, area: 50.0)
    create(:real_estate, crawl_province: hcm, type: "condo", bedrooms: 2, price: 6_000_000_000, area: 70.0)
    create(:real_estate, crawl_province: hcm, type: "house", bedrooms: 3, price: 9_000_000_000, area: 80.0)

    payload = JSON.parse(html[/const DATA = (\{.*?\});/m, 1])

    expect(payload["byType"]["labels"]).to contain_exactly("condo", "house")
    condo_index = payload["byType"]["labels"].index("condo")
    expect(payload["byType"]["counts"][condo_index]).to eq(2)
    expect(payload["byBedrooms"]["counts"].sum).to eq(3)
    expect(payload["priceDistribution"]["counts"].sum).to eq(3)
  end

  it "renders a condo-by-project table with a row per project" do
    create(:real_estate, crawl_province: hcm, type: "condo", project_name: "Vinhomes", bedrooms: 1, price: 2_000_000_000, area: 40.0)
    create(:real_estate, crawl_province: hcm, type: "condo", project_name: "Vinhomes", bedrooms: 2, price: 4_000_000_000, area: 50.0)
    create(:real_estate, crawl_province: hcm, type: "condo", project_name: "Masteri", bedrooms: 1, price: 3_000_000_000, area: 60.0)

    doc = html
    expect(doc).to include("Căn hộ theo dự án")
    expect(doc).to include("Vinhomes")
    expect(doc).to include("Masteri")
    # No dropdown — figures are rendered server-side, not behind a select.
    expect(doc).not_to include("projectSelect")
  end

  it "shows an empty-state note when no condo has a project name" do
    create(:real_estate, crawl_province: hcm, type: "condo", project_name: nil, bedrooms: 2)

    expect(html).to include("Không có dữ liệu căn hộ theo dự án.")
  end

  it "escapes a malicious project name in the table" do
    create(:real_estate, crawl_province: hcm, type: "condo", project_name: "<img src=x>", bedrooms: 1)

    doc = html
    expect(doc).not_to include("<img src=x>")
    expect(doc).to include("&lt;img src=x&gt;")
  end

  it "escapes the province name to prevent HTML injection" do
    evil = create(:province, name: "<script>alert(1)</script>")
    doc = described_class.call(Reports::ProvinceReport.call(evil))

    expect(doc).not_to include("<script>alert(1)</script>")
    expect(doc).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
  end

  it "renders empty-state notes when the province has no listings" do
    expect(html).to include("Không có")
  end

  it "renders a province switcher with the supplied provinces, current one preselected" do
    hanoi = create(:province, name: "Hà Nội")
    doc = described_class.call(Reports::ProvinceReport.call(hcm), provinces: [ hcm, hanoi ])

    expect(doc).to include(%(id="provinceSelect"))
    expect(doc).to include(%(<option value="#{hcm.id}" selected>Hồ Chí Minh</option>))
    expect(doc).to include(%(<option value="#{hanoi.id}">Hà Nội</option>))
    expect(doc).to include("/provinces/' + this.value + '/report.html")
  end

  it "omits the province switcher when no provinces are supplied" do
    expect(html).not_to include(%(id="provinceSelect"))
  end
end
