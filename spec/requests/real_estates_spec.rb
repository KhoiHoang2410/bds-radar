require "rails_helper"

RSpec.describe "RealEstates", type: :request do
  describe "GET /real_estates" do
    it "filters by canonical province_id and includes sub-city (Thủ Đức) rows despite raw-spelling drift" do
      hcm = create(:province, name: "Hồ Chí Minh")
      hanoi = create(:province, name: "Hà Nội")

      create(:real_estate, crawl_province: hcm, province: "Tp Hồ Chí Minh", district_or_city: "Quận 1")
      thu_duc = create(:real_estate, crawl_province: hcm, province: "TPHCM", district_or_city: "Thành phố Thủ Đức")
      create(:real_estate, crawl_province: hanoi, province: "Hà Nội")

      get "/real_estates", params: { province_id: hcm.id }

      body = response.parsed_body.fetch("real_estates")
      expect(body.size).to eq(2) # both HCM rows, regardless of "Tp Hồ Chí Minh" / "TPHCM" drift
      expect(body.map { |r| r["district_or_city"] }).to include("Thành phố Thủ Đức")
      expect(body).to all(include("province_id" => hcm.id))
      expect(body.map { |r| r["id"] }).to include(thu_duc.id)
    end

    it "filters by type, price range, and bbox" do
      cheap = create(:real_estate, type: "condo", price: 2_000_000_000, latitude: 10.78, longitude: 106.65)
      create(:real_estate, type: "condo", price: 9_000_000_000, latitude: 10.78, longitude: 106.65)
      create(:real_estate, type: "house", price: 2_000_000_000, latitude: 21.0, longitude: 105.8)

      get "/real_estates", params: { type: "condo", max_price: 5_000_000_000, bbox: "10.0,106.0,11.0,107.0" }

      ids = response.parsed_body.fetch("real_estates").map { |r| r["id"] }
      expect(ids).to contain_exactly(cheap.id)
    end

    it "defaults to active rows only" do
      active = create(:real_estate, status: "active")
      create(:real_estate, :inactive)

      get "/real_estates"

      expect(response.parsed_body.fetch("real_estates").map { |r| r["id"] }).to contain_exactly(active.id)
    end

    it "rejects an invalid filter with 422" do
      get "/real_estates", params: { type: "mansion" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.fetch("errors")).to have_key("type")
    end

    it "rejects a malformed bbox with 422" do
      get "/real_estates", params: { bbox: "10,106,11" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.fetch("errors")).to have_key("bbox")
    end
  end

  describe "GET /real_estates/:id" do
    it "returns the item with a derived map_url" do
      re = create(:real_estate, latitude: 10.786219, longitude: 106.65734)

      get "/real_estates/#{re.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "id" => re.id,
        "map_url" => "https://www.google.com/maps?q=10.786219,106.65734"
      )
    end

    it "returns 404 for an unknown id" do
      get "/real_estates/0"
      expect(response).to have_http_status(:not_found)
    end
  end
end
