require "rails_helper"

# The vendored post-2025 gazetteer (db/data/wards.json) is what db:seed loads and what
# the matcher resolves against. Verified offline against the committed file.
RSpec.describe "Ward gazetteer" do
  let(:gazetteer) { JSON.parse(File.read(Rails.root.join("db/data/wards.json"))) }

  it "covers the enabled provinces with full post-2025 ward lists" do
    expect(gazetteer.keys).to contain_exactly("Hà Nội", "Hồ Chí Minh", "Khánh Hòa")
    expect(gazetteer["Hồ Chí Minh"].size).to be > 100
    expect(gazetteer.values.sum(&:size)).to be > 300
  end

  it "feeds the matcher: a real post-2025 ward resolves (exact + diacritic-insensitive)" do
    gazetteer.each do |province_name, wards|
      province = Province.find_or_create_by!(name: province_name)
      wards.each { |w| Ward.find_or_create_by!(ward: w, province: province) }
    end
    hanoi = Province.find_by!(name: "Hà Nội")
    w = Ward.find_by!(ward: "Phường Ba Đình", province: hanoi)

    expect(WardMatcher.call(ward: "Phường Ba Đình", province_id: hanoi.id)).to eq(w.id)
    expect(WardMatcher.call(ward: "phuong ba dinh", province_id: hanoi.id)).to eq(w.id)
  end
end
