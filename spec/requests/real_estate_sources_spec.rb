require "rails_helper"

RSpec.describe "RealEstateSources", type: :request do
  describe "GET /real_estate_sources" do
    it "returns stored sources wrapped, with parsed fields and numeric coords/area" do
      source = create(:real_estate_source, area: 43.85, latitude: 10.786219, longitude: 106.65734)

      get "/real_estate_sources"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body.fetch("real_estate_sources")
      expect(body.size).to eq(1)
      expect(body.first).to include(
        "supplier" => source.supplier,
        "external_id" => source.external_id,
        "status" => "active",
        "type" => source.type,
        "area" => 43.85,
        "latitude" => 10.786219,
        "longitude" => 106.65734
      )
    end

    it "filters via ransack q[...] (supplier + status)" do
      create(:real_estate_source, supplier: "nhatot", status: "active")
      inactive = create(:real_estate_source, supplier: "nhatot", status: "inactive")

      get "/real_estate_sources", params: { q: { supplier_eq: "nhatot", status_eq: "inactive" } }

      sources = response.parsed_body.fetch("real_estate_sources")
      expect(sources.map { |s| s["id"] }).to contain_exactly(inactive.id)
    end
  end
end
