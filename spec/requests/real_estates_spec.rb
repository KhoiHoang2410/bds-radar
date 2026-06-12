require "rails_helper"

RSpec.describe "RealEstates", type: :request do
  describe "GET /real_estates" do
    it "filters by canonical province_id (ransack) and includes sub-cities despite raw drift" do
      hcm = create(:province, name: "Hồ Chí Minh")
      hanoi = create(:province, name: "Hà Nội")

      create(:real_estate, crawl_province: hcm, province: "Tp Hồ Chí Minh", district_or_city: "Quận 1")
      thu_duc = create(:real_estate, crawl_province: hcm, province: "TPHCM", district_or_city: "Thành phố Thủ Đức")
      create(:real_estate, crawl_province: hanoi, province: "Hà Nội")

      get "/real_estates", params: { q: { province_id_eq: hcm.id } }

      body = response.parsed_body.fetch("real_estates")
      expect(body.size).to eq(2) # both HCM rows, regardless of "Tp Hồ Chí Minh" / "TPHCM" drift
      expect(body.map { |r| r["district_or_city"] }).to include("Thành phố Thủ Đức")
      expect(body).to all(include("province_id" => hcm.id))
      expect(body.map { |r| r["id"] }).to include(thu_duc.id)
    end

    it "filters by type, price range, and bbox (lat/lng gteq+lteq)" do
      cheap = create(:real_estate, type: "condo", price: 2_000_000_000, latitude: 10.78, longitude: 106.65)
      create(:real_estate, type: "condo", price: 9_000_000_000, latitude: 10.78, longitude: 106.65)
      create(:real_estate, type: "house", price: 2_000_000_000, latitude: 21.0, longitude: 105.8)

      get "/real_estates", params: { q: {
        type_eq: "condo", price_lteq: 5_000_000_000,
        latitude_gteq: 10.0, latitude_lteq: 11.0, longitude_gteq: 106.0, longitude_lteq: 107.0
      } }

      ids = response.parsed_body.fetch("real_estates").map { |r| r["id"] }
      expect(ids).to contain_exactly(cheap.id)
    end

    it "defaults to active rows only, but q[status_eq] can opt into inactive" do
      active = create(:real_estate, status: "active")
      inactive = create(:real_estate, :inactive)

      get "/real_estates"
      expect(response.parsed_body.fetch("real_estates").map { |r| r["id"] }).to contain_exactly(active.id)

      get "/real_estates", params: { q: { status_eq: "inactive" } }
      expect(response.parsed_body.fetch("real_estates").map { |r| r["id"] }).to contain_exactly(inactive.id)
    end

    it "ignores an unknown ransack predicate instead of erroring" do
      create(:real_estate)
      get "/real_estates", params: { q: { bogus_attribute_eq: "x" } }
      expect(response).to have_http_status(:ok)
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

    it "exposes the promoted listing detail columns" do
      re = create(:real_estate, bedrooms: 3, bathrooms: 2, title: "Bán căn hộ 3PN")

      get "/real_estates/#{re.id}"

      expect(response.parsed_body).to include(
        "bedrooms" => 3, "bathrooms" => 2, "title" => "Bán căn hộ 3PN"
      )
      expect(response.parsed_body).to have_key("posted_at")
    end

    it "filters by bedrooms via ransack" do
      two = create(:real_estate, bedrooms: 2)
      create(:real_estate, bedrooms: 4)

      get "/real_estates", params: { q: { bedrooms_eq: 2 } }

      expect(response.parsed_body.fetch("real_estates").map { |r| r["id"] }).to contain_exactly(two.id)
    end

    it "returns 404 for an unknown id" do
      get "/real_estates/0"
      expect(response).to have_http_status(:not_found)
    end
  end
end
