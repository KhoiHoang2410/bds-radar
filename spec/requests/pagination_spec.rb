require "rails_helper"

# Shared pagy pagination across all index endpoints: default page 1, 25/page, cap 100.
RSpec.describe "Index pagination (pagy)", type: :request do
  describe "GET /provinces" do
    before { create_list(:province, 30) }

    it "defaults to page 1 with 25 items + pagination metadata" do
      get "/provinces"

      body = response.parsed_body
      expect(body.fetch("provinces").size).to eq(25)
      expect(body.fetch("pagination")).to include(
        "page" => 1, "per_page" => 25, "total_count" => 30, "total_pages" => 2
      )
    end

    it "returns the requested page" do
      get "/provinces", params: { page: 2 }

      expect(response.parsed_body.fetch("provinces").size).to eq(5)
      expect(response.parsed_body.fetch("pagination")).to include("page" => 2)
    end

    it "honors a custom per_page" do
      get "/provinces", params: { per_page: 10 }

      expect(response.parsed_body.fetch("provinces").size).to eq(10)
      expect(response.parsed_body.fetch("pagination")).to include("per_page" => 10, "total_pages" => 3)
    end

    it "clamps per_page to the cap of 100 (no error)" do
      get "/provinces", params: { per_page: 1000 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("pagination")).to include("per_page" => 100)
    end

    it "returns an empty page (not an error) past the end" do
      get "/provinces", params: { page: 99 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("provinces")).to be_empty
    end
  end

  it "GET /real_estates includes pagination metadata" do
    create_list(:real_estate, 3)
    get "/real_estates"
    expect(response.parsed_body.fetch("pagination")).to include("page" => 1, "per_page" => 25)
  end

  it "GET /real_estate_sources includes pagination metadata" do
    create(:real_estate_source)
    get "/real_estate_sources"
    expect(response.parsed_body.fetch("pagination")).to include("page" => 1, "per_page" => 25, "total_count" => 1)
  end
end
