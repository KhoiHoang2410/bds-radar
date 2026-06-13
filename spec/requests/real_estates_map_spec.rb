require "rails_helper"

RSpec.describe "RealEstates map", type: :request do
  describe "GET /real_estates/map" do
    it "returns an empty cell set for a bbox with no listings" do
      create(:real_estate, latitude: 10.78, longitude: 106.65)

      get "/real_estates/map", params: { q: {
        latitude_gteq: 0.0, latitude_lteq: 1.0, longitude_gteq: 0.0, longitude_lteq: 1.0
      } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("cells")).to eq([])
      expect(response.parsed_body.fetch("precision")).to eq(2)
    end

    it "aggregates listings sharing a bin: count + median_price + price_per_m2" do
      # All three round to (10.78, 106.65) at precision 2 → one cell.
      create(:real_estate, latitude: 10.7811, longitude: 106.6512, price: 1_000_000_000, area: 50.0)
      create(:real_estate, latitude: 10.7822, longitude: 106.6523, price: 2_000_000_000, area: 50.0)
      create(:real_estate, latitude: 10.7843, longitude: 106.6534, price: 3_000_000_000, area: 50.0)
      # A far-away listing that the bbox below excludes.
      create(:real_estate, latitude: 21.0, longitude: 105.8, price: 9_000_000_000, area: 100.0)

      get "/real_estates/map", params: { q: {
        latitude_gteq: 10.0, latitude_lteq: 11.0, longitude_gteq: 106.0, longitude_lteq: 107.0
      } }

      cells = response.parsed_body.fetch("cells")
      expect(cells.size).to eq(1)
      cell = cells.first
      expect(cell["lat"]).to eq(10.78)
      expect(cell["lng"]).to eq(106.65)
      expect(cell["count"]).to eq(3)
      expect(cell["median_price"]).to eq(2_000_000_000) # median of 1B, 2B, 3B
      # median of per-listing price/area: 20M, 40M, 60M → 40M
      expect(cell["price_per_m2"]).to eq(40_000_000.0)
    end

    it "splits listings into separate bins by rounded coordinate" do
      create(:real_estate, latitude: 10.781, longitude: 106.651, price: 1_000_000_000)
      create(:real_estate, latitude: 10.792, longitude: 106.661, price: 2_000_000_000)

      get "/real_estates/map"

      cells = response.parsed_body.fetch("cells")
      expect(cells.map { |c| [ c["lat"], c["lng"] ] }).to contain_exactly([ 10.78, 106.65 ], [ 10.79, 106.66 ])
      expect(cells.map { |c| c["count"] }).to all(eq(1))
    end

    it "respects ransack filters (type_eq) before aggregating" do
      create(:real_estate, type: "condo", latitude: 10.781, longitude: 106.651, price: 2_000_000_000, area: 40.0)
      create(:real_estate, type: "house", latitude: 10.782, longitude: 106.652, price: 8_000_000_000, area: 40.0)

      get "/real_estates/map", params: { q: { type_eq: "condo" } }

      cells = response.parsed_body.fetch("cells")
      expect(cells.size).to eq(1)
      expect(cells.first["count"]).to eq(1)
      expect(cells.first["median_price"]).to eq(2_000_000_000)
    end

    it "defaults to active rows but q[status_eq] can opt into inactive" do
      create(:real_estate, status: "active", latitude: 10.781, longitude: 106.651)
      create(:real_estate, :inactive, latitude: 10.781, longitude: 106.651)

      get "/real_estates/map"
      expect(response.parsed_body.fetch("cells").first["count"]).to eq(1)

      get "/real_estates/map", params: { q: { status_eq: "inactive" } }
      expect(response.parsed_body.fetch("cells").first["count"]).to eq(1)

      get "/real_estates/map", params: { q: { status_eq: "active" } }
      expect(response.parsed_body.fetch("cells").first["count"]).to eq(1)
    end

    it "honours a coarser precision param (merging bins)" do
      create(:real_estate, latitude: 10.781, longitude: 106.651)
      create(:real_estate, latitude: 10.792, longitude: 106.661)

      get "/real_estates/map", params: { precision: 1 }

      body = response.parsed_body
      expect(body.fetch("precision")).to eq(1)
      cells = body.fetch("cells")
      expect(cells.size).to eq(1) # both round to (10.8, 106.7) at precision 1
      expect(cells.first["count"]).to eq(2)
    end
  end
end
