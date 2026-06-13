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

  it "copies the promoted listing detail columns (bedrooms/bathrooms/posted_at/title)" do
    posted = Time.zone.local(2026, 5, 1, 9, 0)
    source = create(:real_estate_source, crawl_province: hcm, bedrooms: 3, bathrooms: 2,
                                         posted_at: posted, title: "Bán căn hộ 3PN")

    run

    re = RealEstate.find_by(real_estate_source_id: source.id)
    expect(re).to have_attributes(bedrooms: 3, bathrooms: 2, posted_at: posted, title: "Bán căn hộ 3PN")
  end

  it "promotes the condo project name + id (nullable)" do
    condo = create(:real_estate_source, crawl_province: hcm, type: "condo",
                                        project_name: "Akari City", project_external_id: "12345")
    plain = create(:real_estate_source, crawl_province: hcm, project_name: nil, project_external_id: nil)

    run

    expect(RealEstate.find_by(real_estate_source_id: condo.id))
      .to have_attributes(project_name: "Akari City", project_external_id: "12345")
    expect(RealEstate.find_by(real_estate_source_id: plain.id))
      .to have_attributes(project_name: nil, project_external_id: nil)
  end

  it "resolves ward_id when the matcher finds one, leaves it nil otherwise" do
    w = create(:ward, ward: "Phường Bến Nghé", province: hcm)
    matched = create(:real_estate_source, crawl_province: hcm, ward: "Phường Bến Nghé")
    unmatched = create(:real_estate_source, crawl_province: hcm, ward: "Phường Không Có")

    run

    expect(RealEstate.find_by(real_estate_source_id: matched.id).ward_id).to eq(w.id)
    expect(RealEstate.find_by(real_estate_source_id: unmatched.id).ward_id).to be_nil
  end

  it "skips a source missing a mandatory field (no partial RealEstate)" do
    complete = create(:real_estate_source, crawl_province: hcm)
    incomplete = create(:real_estate_source, crawl_province: hcm, price: nil)

    run

    expect(RealEstate.find_by(real_estate_source_id: complete.id)).to be_present
    expect(RealEstate.find_by(real_estate_source_id: incomplete.id)).to be_nil
  end

  it "skips a source with no images (image_urls must be non-empty)" do
    create(:real_estate_source, crawl_province: hcm, image_urls: [])

    run

    expect(RealEstate.count).to eq(0)
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
