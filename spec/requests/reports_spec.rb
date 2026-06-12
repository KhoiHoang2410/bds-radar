require "rails_helper"

RSpec.describe "Reports", type: :request do
  describe "GET /provinces/:province_id/report" do
    it "renders a PDF for the province" do
      hcm = create(:province, name: "Hồ Chí Minh")
      create(:real_estate, crawl_province: hcm, type: "condo", bedrooms: 2, price: 4_000_000_000, area: 50.0)
      create(:real_estate, crawl_province: hcm, type: "land", bedrooms: nil, price: 9_000_000_000, area: 100.0)

      get "/provinces/#{hcm.id}/report"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.body[0, 4]).to eq("%PDF")
    end

    it "renders even when the province has no listings" do
      empty = create(:province, name: "Hà Nội")

      get "/provinces/#{empty.id}/report"

      expect(response).to have_http_status(:ok)
      expect(response.body[0, 4]).to eq("%PDF")
    end

    it "404s for an unknown province" do
      get "/provinces/0/report"
      expect(response).to have_http_status(:not_found)
    end
  end
end
