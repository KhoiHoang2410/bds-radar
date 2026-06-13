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
    expect(doc).to include("Hồ Chí Minh")
    expect(doc).to include("cdn.jsdelivr.net/npm/chart.js")
    %w[byType byBedrooms avgPrice priceDist].each do |canvas|
      expect(doc).to include(%(id="#{canvas}"))
    end
  end

  it "renders land analysis grouped by ward, each with its area-bucket table" do
    create(:real_estate, crawl_province: hcm, type: "land", ward: "Phường 1", price: 2_000_000_000, area: 40.0)
    create(:real_estate, crawl_province: hcm, type: "land", ward: "Phường 2", price: 9_000_000_000, area: 200.0)

    doc = html
    expect(doc).to include("Đất — phân tích theo phường")
    expect(doc).to include("Phường 1")
    expect(doc).to include("Phường 2")
    expect(doc).to include("< 30 m²")
    expect(doc).to include("≥ 150 m²")
    # land is no longer analysed by bedroom
    expect(doc).not_to include("Đất — giá theo số phòng ngủ")
  end

  it "escapes a malicious ward name in the land section" do
    create(:real_estate, crawl_province: hcm, type: "land", ward: "<b>x</b>", price: 2_000_000_000, area: 40.0)

    doc = html
    expect(doc).not_to include("<b>x</b>")
    expect(doc).to include("&lt;b&gt;x&lt;/b&gt;")
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

  it "escapes the province name to prevent HTML injection" do
    evil = create(:province, name: "<script>alert(1)</script>")
    doc = described_class.call(Reports::ProvinceReport.call(evil))

    expect(doc).not_to include("<script>alert(1)</script>")
    expect(doc).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
  end

  it "renders empty-state notes when the province has no listings" do
    expect(html).to include("Không có")
  end
end
