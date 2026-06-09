require "rails_helper"

RSpec.describe "Provinces", type: :request do
  describe "GET /provinces" do
    it "returns all provinces wrapped, with the crawl-control fields" do
      create(:province, name: "Hồ Chí Minh", alternatives: [ "TPHCM", "Sài Gòn" ], schedule_fetch: true, fetch_page_depth: 5)
      create(:province, name: "Lai Châu")

      get "/provinces"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      names = body.fetch("provinces").map { |p| p.fetch("name") }
      expect(names).to contain_exactly("Hồ Chí Minh", "Lai Châu")

      hcm = body["provinces"].find { |p| p["name"] == "Hồ Chí Minh" }
      expect(hcm).to include(
        "alternatives" => [ "TPHCM", "Sài Gòn" ],
        "schedule_fetch" => true,
        "fetch_page_depth" => 5
      )
    end
  end

  describe "PATCH /provinces/:id" do
    it "toggles schedule_fetch and adjusts depth" do
      province = create(:province, schedule_fetch: false, fetch_page_depth: 5)

      patch "/provinces/#{province.id}", params: { schedule_fetch: true, fetch_page_depth: 8 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("schedule_fetch" => true, "fetch_page_depth" => 8)
      expect(province.reload.schedule_fetch).to be(true)
      expect(province.fetch_page_depth).to eq(8)
    end

    it "rejects an invalid depth with 422 + errors" do
      province = create(:province, fetch_page_depth: 5)

      patch "/provinces/#{province.id}", params: { fetch_page_depth: 0 }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.fetch("errors")).to have_key("fetch_page_depth")
      expect(province.reload.fetch_page_depth).to eq(5)
    end

    it "rejects a non-JSON content type with 415" do
      province = create(:province)

      patch "/provinces/#{province.id}", params: "schedule_fetch=true",
            headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }

      expect(response).to have_http_status(:unsupported_media_type)
    end

    it "returns 404 for an unknown province" do
      patch "/provinces/0", params: { schedule_fetch: true }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
