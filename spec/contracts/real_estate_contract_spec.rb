require "rails_helper"

RSpec.describe RealEstateContract do
  def valid_attrs(**overrides)
    {
      latitude: 10.786219,
      longitude: 106.65734,
      province_id: 1,
      real_estate_source_id: 1,
      price: 5_000_000_000,
      area: 50.0,
      type: "house",
      status: "active",
      province: "Tp Hồ Chí Minh",
      ward: "Phường 7",
      district_or_city: "Quận Tân Bình",
      image_urls: [ "https://cdn.chotot.com/a.jpg" ],
      source_urls: [ "https://www.nhatot.com/1.htm" ]
    }.merge(overrides)
  end

  it "passes when every mandatory field is present" do
    expect(described_class.new.call(valid_attrs)).to be_success
  end

  it "ignores the optional, by-design-nullable fields" do
    attrs = valid_attrs.merge(ward_id: nil, bedrooms: nil, bathrooms: nil, posted_at: nil, title: nil)
    expect(described_class.new.call(attrs)).to be_success
  end

  %i[latitude longitude province_id real_estate_source_id price area type status
     province ward district_or_city].each do |field|
    it "fails when #{field} is missing" do
      expect(described_class.new.call(valid_attrs(**{ field => nil }))).to be_failure
    end
  end

  it "fails when image_urls is empty" do
    expect(described_class.new.call(valid_attrs(image_urls: []))).to be_failure
  end

  it "fails when source_urls is empty" do
    expect(described_class.new.call(valid_attrs(source_urls: []))).to be_failure
  end
end
