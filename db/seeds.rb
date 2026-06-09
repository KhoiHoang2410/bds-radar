# Post-2025 canonical Vietnamese provinces/cities (63 → 34, districts abolished).
# Source: 2025 Vietnamese administrative reform (effective 2025-07-01).
# `schedule_fetch` is enabled for the v1 coverage set only (HCM, Hà Nội, Khánh Hòa —
# the last covers Nha Trang). `alternatives` hold common spellings/aliases the
# WardCity matcher and province lookups canonicalize against.

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

# WardCity — canonical (ward, province) labels for the matcher (#6).
# ⚠️ STARTER SET, not a complete gazetteer: the post-2025 reform renamed/merged
# wards mid-migration and suppliers still emit legacy ward strings, so ward_city_id
# is best-effort/nullable by design (coords are identity — ADR-0001). This seeds a
# representative sample for the enabled provinces; the full ward list is a separate
# data-load task. `[ward, province, ward_alternatives]`.
WARD_CITIES = [
  [ "Phường Bến Nghé", "Hồ Chí Minh", [ "Ben Nghe" ] ],
  [ "Phường Bến Thành", "Hồ Chí Minh", [ "Ben Thanh" ] ],
  [ "Phường Tân Định", "Hồ Chí Minh", [ "Tan Dinh" ] ],
  [ "Phường Thảo Điền", "Hồ Chí Minh", [ "Thao Dien" ] ],
  [ "Phường 1", "Hồ Chí Minh", [] ],
  [ "Phường 4", "Hồ Chí Minh", [] ],
  [ "Phường Hàng Bạc", "Hà Nội", [ "Hang Bac" ] ],
  [ "Phường Cửa Nam", "Hà Nội", [ "Cua Nam" ] ],
  [ "Phường Dịch Vọng", "Hà Nội", [ "Dich Vong" ] ],
  [ "Phường Lộc Thọ", "Khánh Hòa", [ "Loc Tho" ] ],
  [ "Phường Vĩnh Hải", "Khánh Hòa", [ "Vinh Hai" ] ]
].freeze

WARD_CITIES.each do |ward, province, ward_alternatives|
  wc = WardCity.find_or_initialize_by(ward: ward, province: province)
  wc.ward_alternatives = ward_alternatives
  wc.save!
end

puts "Seeded #{WardCity.count} ward_cities (starter set)"
