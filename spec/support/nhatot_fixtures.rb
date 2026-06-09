require "json"

module NhatotFixtures
  def nhatot_ads(name = "ad_listing_hcm")
    JSON.parse(File.read(Rails.root.join("spec/fixtures/nhatot/#{name}.json"))).fetch("ads")
  end

  # Stub the gateway: page 0 (o=0) returns `ads`; every other offset returns no ads
  # (so the job's page loop terminates). Order matters — WebMock prefers the LAST
  # matching stub, so the general "empty" stub is declared before the specific o=0.
  def stub_nhatot(region_v2:, ads:)
    stub_request(:get, /gateway\.chotot\.com/)
      .with(query: hash_including("region_v2" => region_v2.to_s))
      .to_return(status: 200, body: { ads: [] }.to_json, headers: { "Content-Type" => "application/json" })

    stub_request(:get, /gateway\.chotot\.com/)
      .with(query: hash_including("region_v2" => region_v2.to_s, "o" => "0"))
      .to_return(status: 200, body: { ads: ads }.to_json, headers: { "Content-Type" => "application/json" })
  end
end

RSpec.configure { |c| c.include NhatotFixtures }
