require "json"

module Suppliers
  # nhatot — list-complete, plain HTTP JSON gateway, no auth.
  # Hard-codes its own province→region_v2 map + URI (the DB owns *what* to crawl;
  # the Supplier owns *how* to address it).
  class Nhatot < Base
    GATEWAY = "https://gateway.chotot.com/v1/public/ad-listing".freeze
    SITE = "https://www.nhatot.com".freeze
    LIMIT = 20

    # Proven live (spec §2): region_v2 per enabled province.
    REGION_CODES = {
      "Hồ Chí Minh" => 13000,
      "Hà Nội" => 12000,
      "Khánh Hòa" => 7044
    }.freeze

    # category → canonical type. ⚠️ `size` is m²; `area` is the district code (the trap).
    CATEGORY_TYPES = { 1010 => "condo", 1020 => "house", 1040 => "land" }.freeze

    # Yields each raw ad hash for one page; returns the number yielded (0 ⇒ no more pages).
    def each_listing(province, page)
      code = REGION_CODES.fetch(province.name)
      offset = page * LIMIT
      url = "#{GATEWAY}?cg=1000&st=s,k&region_v2=#{code}&limit=#{LIMIT}&o=#{offset}"
      ads = JSON.parse(get(url)).fetch("ads", [])
      ads.each { |ad| yield ad }
      ads.size
    end

    def normalize(raw)
      Listing.new(
        supplier: "nhatot",
        external_id: raw["list_id"].to_s,
        source_url: "#{SITE}/#{raw['list_id']}.htm",
        type: CATEGORY_TYPES.fetch(raw["category"], "other"),
        price: raw["price"],
        area: raw["size"], # m² — NOT `area` (that is the district code)
        address: build_address(raw),
        province: raw["region_name"],       # raw drift, e.g. "Tp Hồ Chí Minh"
        district_or_city: raw["area_name"],  # district, e.g. "Quận Tân Bình"
        ward: raw["ward_name"],
        street: [ raw["street_number"], raw["street_name"] ].compact_blank.join(" ").presence,
        image_urls: Array(raw["images"]),
        latitude: raw["latitude"],
        longitude: raw["longitude"],
        raw_data: raw
      )
    end

    private

    def build_address(raw)
      [ raw["street_name"], raw["ward_name"], raw["area_name"], raw["region_name"] ].compact_blank.join(", ")
    end
  end
end
