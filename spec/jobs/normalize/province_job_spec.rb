require "rails_helper"

RSpec.describe Normalize::ProvinceJob do
  let(:hcm) { create(:province, name: "Hồ Chí Minh") }

  def run
    described_class.new.perform(hcm.id)
  end

  it "builds one RealEstate per source, copying coords/admin path/price/type and canonical province_id" do
    source = create(:real_estate_source, crawl_province: hcm, province: "Tp Hồ Chí Minh",
                                         district_or_city: "Quận Tân Bình", ward: "Phường 7",
                                         area: 43.85, price: 5_500_000_000, type: "house",
                                         latitude: 10.786219, longitude: 106.65734,
                                         source_url: "https://www.nhatot.com/9.htm")

    run

    re = RealEstate.find_by(real_estate_source_id: source.id)
    expect(re).to have_attributes(
      province_id: hcm.id, province: "Tp Hồ Chí Minh", district_or_city: "Quận Tân Bình",
      ward: "Phường 7", price: 5_500_000_000, type: "house", status: "active"
    )
    expect(re.latitude.to_f).to eq(10.786219)
    expect(re.source_urls).to eq([ "https://www.nhatot.com/9.htm" ])
  end

  it "resolves ward_city_id when the matcher finds one, leaves it nil otherwise" do
    wc = create(:ward_city, ward: "Phường Bến Nghé", province: "Hồ Chí Minh")
    matched = create(:real_estate_source, crawl_province: hcm, ward: "Phường Bến Nghé")
    unmatched = create(:real_estate_source, crawl_province: hcm, ward: "Phường Không Có")

    run

    expect(RealEstate.find_by(real_estate_source_id: matched.id).ward_city_id).to eq(wc.id)
    expect(RealEstate.find_by(real_estate_source_id: unmatched.id).ward_city_id).to be_nil
  end

  it "propagates source status (inactive source ⇒ inactive RealEstate)" do
    active = create(:real_estate_source, crawl_province: hcm, status: "active")
    inactive = create(:real_estate_source, :inactive, crawl_province: hcm)

    run

    expect(RealEstate.find_by(real_estate_source_id: active.id).status).to eq("active")
    expect(RealEstate.find_by(real_estate_source_id: inactive.id).status).to eq("inactive")
  end

  it "is idempotent — re-running never duplicates a RealEstate per source" do
    create(:real_estate_source, crawl_province: hcm)
    run
    run
    expect(RealEstate.count).to eq(1)
  end

  it "tags a Thủ Đức listing with province=HCM so a province search includes it" do
    source = create(:real_estate_source, crawl_province: hcm, province: "Tp Hồ Chí Minh",
                                         district_or_city: "Thành phố Thủ Đức", ward: "Phường Thảo Điền")
    run

    re = RealEstate.find_by(real_estate_source_id: source.id)
    expect(re.province_id).to eq(hcm.id)
    expect(re.district_or_city).to eq("Thành phố Thủ Đức")
  end
end
