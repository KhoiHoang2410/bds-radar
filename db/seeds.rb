# Post-2025 canonical Vietnamese provinces/cities (63 → 34, districts abolished).
# Source: 2025 Vietnamese administrative reform (effective 2025-07-01).
# `schedule_fetch` is enabled for the v1 coverage set only (HCM, Hà Nội, Khánh Hòa —
# the last covers Nha Trang). `alternatives` hold common spellings/aliases that
# province lookups canonicalize against.

ENABLED = [ "Hồ Chí Minh", "Hà Nội", "Khánh Hòa" ].freeze

# name => alternatives. Names absent here get no aliases (no common variants).
PROVINCES = {
  "Hà Nội"        => [ "Hanoi", "Ha Noi", "HN" ],
  "Hồ Chí Minh"   => [ "TPHCM", "TP HCM", "TP. Hồ Chí Minh", "Tp Hồ Chí Minh", "Sài Gòn", "Saigon", "Ho Chi Minh", "HCM" ],
  "Hải Phòng"     => [ "Hai Phong" ],
  "Huế"           => [ "Hue", "Thừa Thiên Huế", "Thua Thien Hue" ],
  "Đà Nẵng"       => [ "Da Nang", "Danang" ],
  "Cần Thơ"       => [ "Can Tho" ],
  "Khánh Hòa"     => [ "Khanh Hoa", "Nha Trang" ],
  "Lai Châu"      => [],
  "Điện Biên"     => [],
  "Sơn La"        => [],
  "Lạng Sơn"      => [],
  "Quảng Ninh"    => [],
  "Thanh Hóa"     => [],
  "Nghệ An"       => [],
  "Hà Tĩnh"       => [],
  "Cao Bằng"      => [],
  "Tuyên Quang"   => [],
  "Lào Cai"       => [],
  "Thái Nguyên"   => [],
  "Phú Thọ"       => [],
  "Bắc Ninh"      => [],
  "Hưng Yên"      => [],
  "Ninh Bình"     => [],
  "Quảng Trị"     => [],
  "Quảng Ngãi"    => [],
  "Gia Lai"       => [],
  "Lâm Đồng"      => [],
  "Đắk Lắk"       => [ "Dak Lak" ],
  "Đồng Nai"      => [],
  "Tây Ninh"      => [],
  "Vĩnh Long"     => [],
  "Đồng Tháp"     => [],
  "Cà Mau"        => [],
  "An Giang"      => []
}.freeze

PROVINCES.each do |name, alternatives|
  province = Province.find_or_initialize_by(name: name)
  province.alternatives = alternatives
  province.schedule_fetch = ENABLED.include?(name)
  province.fetch_page_depth ||= 5
  province.save!
end

puts "Seeded #{Province.count} provinces (#{Province.scheduled.count} scheduled: #{Province.scheduled.pluck(:name).join(', ')})"

# Ward — canonical post-2025 (ward, province_id) gazetteer for the matcher (#6).
# Vendored offline in db/data/wards.json (sourced from provinces.open-api.vn v2, the
# post-2025 2-tier dataset; refresh with `rake gazetteer:refresh`). The JSON is keyed
# by canonical province name; we resolve it to the seeded Province's id. Seeding is
# network-free + reproducible. Still best-effort/nullable by design — suppliers emit
# legacy ward names mid-migration, and coords remain the identity (ADR-0001).
ward_data = JSON.parse(File.read(Rails.root.join("db/data/wards.json")))
ward_data.each do |province_name, wards|
  province = Province.find_by!(name: province_name)
  wards.each do |ward|
    Ward.find_or_create_by!(ward: ward, province: province)
  end
end

puts "Seeded #{Ward.count} wards (full post-2025 gazetteer: #{ward_data.transform_values(&:size)})"
