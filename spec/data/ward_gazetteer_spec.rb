require "rails_helper"

# The vendored post-2025 gazetteer (db/data/ward_cities.json) is what db:seed loads
# and what the matcher resolves against. Verified offline against the committed file.
RSpec.describe "Ward gazetteer" do
  let(:gazetteer) { JSON.parse(File.read(Rails.root.join("db/data/ward_cities.json"))) }

  it "covers the enabled provinces with full post-2025 ward lists" do
    expect(gazetteer.keys).to contain_exactly("Hà Nội", "Hồ Chí Minh", "Khánh Hòa")
    expect(gazetteer["Hồ Chí Minh"].size).to be > 100
    expect(gazetteer.values.sum(&:size)).to be > 300
  end

  it "feeds the matcher: a real post-2025 ward resolves (exact + diacritic-insensitive)" do
    gazetteer.each do |province, wards|
      wards.each { |w| WardCity.find_or_create_by!(ward: w, province: province) }
    end
    wc = WardCity.find_by!(ward: "Phường Ba Đình", province: "Hà Nội")

    expect(WardCityMatcher.call(ward: "Phường Ba Đình", province: "Hà Nội")).to eq(wc.id)
    expect(WardCityMatcher.call(ward: "phuong ba dinh", province: "Ha Noi")).to eq(wc.id)
  end
end
