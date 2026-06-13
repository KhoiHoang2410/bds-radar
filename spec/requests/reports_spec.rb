require "rails_helper"

RSpec.describe "Reports", type: :request do
  def seed_listings(province)
    create(:real_estate, crawl_province: province, type: "condo", bedrooms: 2, price: 4_000_000_000, area: 50.0)
    create(:real_estate, crawl_province: province, type: "land", bedrooms: nil, price: 9_000_000_000, area: 100.0)
  end

  describe "GET /provinces/:province_id/report.pdf" do
    it "renders a PDF for the province" do
      hcm = create(:province, name: "Hồ Chí Minh")
      seed_listings(hcm)

      get "/provinces/#{hcm.id}/report.pdf"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.body[0, 4]).to eq("%PDF")
    end

    it "sets the PDF title (browser tab) to 'Report for <province>'" do
      province = create(:province, name: "Hanoi")

      get "/provinces/#{province.id}/report.pdf"

      # Prawn stores /Title as a UTF-16BE hex string with a BOM.
      hex = "feff" + "Report for Hanoi".encode("UTF-16BE").bytes.map { |b| format("%02x", b) }.join
      expect(response.body).to include("/Title <#{hex}>")
    end

    it "renders even when the province has no listings" do
      empty = create(:province, name: "Hà Nội")

      get "/provinces/#{empty.id}/report.pdf"

      expect(response).to have_http_status(:ok)
      expect(response.body[0, 4]).to eq("%PDF")
    end
  end

  describe "GET /provinces/:province_id/report.html" do
    it "renders an HTML report with charts for the province" do
      hcm = create(:province, name: "Hồ Chí Minh")
      seed_listings(hcm)

      get "/provinces/#{hcm.id}/report.html"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("Hồ Chí Minh")
      expect(response.body).to include("<canvas id=\"byType\">")
    end

    it "is the default format when no extension is given" do
      hcm = create(:province, name: "Hồ Chí Minh")

      get "/provinces/#{hcm.id}/report"

      expect(response.media_type).to eq("text/html")
    end
  end

  it "404s for an unknown province" do
    get "/provinces/0/report.pdf"
    expect(response).to have_http_status(:not_found)
  end
end
