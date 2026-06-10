require "rails_helper"

RSpec.describe RealEstateSource, type: :model do
  it "has a valid factory" do
    expect(build(:real_estate_source)).to be_valid
  end

  it "requires supplier and external_id" do
    expect(build(:real_estate_source, supplier: nil)).not_to be_valid
    expect(build(:real_estate_source, external_id: nil)).not_to be_valid
  end

  it "enforces unique external_id within a supplier, but allows reuse across suppliers" do
    create(:real_estate_source, supplier: "nhatot", external_id: "123")
    expect(build(:real_estate_source, supplier: "nhatot", external_id: "123")).not_to be_valid
    expect(build(:real_estate_source, supplier: "mogi", external_id: "123")).to be_valid
  end

  it "only allows known statuses" do
    expect(build(:real_estate_source, status: "bogus")).not_to be_valid
  end

  it "exposes the crawl province via #crawl_province (not the raw `province` string)" do
    source = create(:real_estate_source, province: "Tp Hồ Chí Minh")
    expect(source.crawl_province).to be_a(Province)
    expect(source.province).to eq("Tp Hồ Chí Minh") # raw string attribute, not the association
  end

  describe "scopes" do
    it "partitions active / inactive" do
      active = create(:real_estate_source, status: "active")
      inactive = create(:real_estate_source, :inactive)

      expect(described_class.active).to contain_exactly(active)
      expect(described_class.inactive).to contain_exactly(inactive)
    end
  end
end
