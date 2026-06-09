require "rails_helper"

# mogi reuses Fetch::SupplierJob (#3) unchanged — this covers the list+detail path
# and the fetch-then-store crash safety for its many detail fetches.
RSpec.describe Fetch::SupplierJob, "for mogi" do
  let(:province) { create(:province, name: "Hồ Chí Minh", fetch_page_depth: 1) }
  let(:list_url) { "https://mogi.vn/ho-chi-minh/mua-nha-dat" }
  let(:url1) { "https://mogi.vn/q/mua-nha-rieng/a-id111" }
  let(:url2) { "https://mogi.vn/q/mua-can-ho/b-id222" }

  def run
    described_class.new.perform("mogi", province.id)
  end

  it "crawls list→detail and upserts active sources stamped with province_id" do
    stub_request(:get, list_url).to_return(status: 200, body: mogi_list_with(url1, url2))
    stub_request(:get, url1).to_return(status: 200, body: mogi_detail_html)
    stub_request(:get, url2).to_return(status: 200, body: mogi_detail_html)

    run

    expect(RealEstateSource.where(supplier: "mogi").count).to eq(2)
    src = RealEstateSource.find_by(supplier: "mogi", external_id: "111")
    expect(src).to have_attributes(status: "active", province_id: province.id, price: 8_250_000_000)
  end

  it "writes nothing when a detail fetch fails mid-unit (fetch-then-store)" do
    stub_request(:get, list_url).to_return(status: 200, body: mogi_list_with(url1, url2))
    stub_request(:get, url1).to_return(status: 200, body: mogi_detail_html)
    stub_request(:get, url2).to_return(status: 500, body: "")

    expect { run }.to raise_error(Suppliers::Base::FetchError)
    expect(RealEstateSource.where(supplier: "mogi").count).to eq(0)
  end
end
