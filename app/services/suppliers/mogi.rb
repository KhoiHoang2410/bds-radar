require "nokogiri"

module Suppliers
  # mogi — list + detail, server-rendered HTML. each_listing fetches the province
  # list page, extracts detail URLs, then fetches each detail (ward + coords only
  # live on the detail page). Plugs into the same Base + Fetch::SupplierJob contract.
  class Mogi < Base
    SITE = "https://mogi.vn".freeze

    PROVINCE_SLUGS = {
      "Hồ Chí Minh" => "ho-chi-minh",
      "Hà Nội" => "ha-noi",
      "Khánh Hòa" => "khanh-hoa"
    }.freeze

    DETAIL_ID = /-id\d+\z/

    def each_listing(province, page)
      slug = PROVINCE_SLUGS.fetch(province.name)
      urls = extract_detail_urls(get(list_url(slug, page)))
      urls.each { |url| yield parse_detail(url, get(url)) }
      urls.size
    end

    def normalize(raw)
      Listing.new(
        supplier: "mogi",
        external_id: raw["external_id"],
        source_url: raw["url"],
        type: raw["type"],
        price: raw["price"],
        area: raw["area"],
        address: raw["address"],
        province: raw["city"],            # raw supplier string (e.g. "TPHCM")
        district_or_city: raw["district"],
        ward: raw["ward"],
        street: raw["street"],
        image_urls: raw["images"],
        latitude: raw["latitude"],
        longitude: raw["longitude"],
        raw_data: raw
      )
    end

    # Unique detail-page URLs from a list page (hrefs are a mix of relative + absolute).
    def extract_detail_urls(list_html)
      Nokogiri::HTML(list_html).css("a[href]")
        .filter_map { |a| a["href"] }
        .select { |href| href.match?(DETAIL_ID) }
        .map { |href| href.start_with?("http") ? href : SITE + href }
        .select { |url| url.start_with?(SITE) }
        .uniq
    end

    # Parse one detail page into a structured raw hash (stored as raw_data — we keep
    # the parsed shape, not the megabytes of HTML).
    def parse_detail(url, html)
      doc = Nokogiri::HTML(html)
      address = doc.css(".address").first&.text&.strip.to_s
      ward, district, city, street = split_address(address)
      lat, lng = coordinates(html)

      {
        "url" => url,
        "external_id" => url[/-id(\d+)/, 1],
        "type" => type_from_url(url),
        "price" => VnPrice.parse(doc.css(".price").first&.text),
        "area" => area_from(doc),
        "address" => address,
        "ward" => ward,
        "district" => district,
        "city" => city,
        "street" => street,
        "latitude" => lat,
        "longitude" => lng,
        "images" => image_urls(doc)
      }
    end

    private

    def list_url(slug, page)
      url = "#{SITE}/#{slug}/mua-nha-dat"
      page.positive? ? "#{url}?cp=#{page + 1}" : url
    end

    def type_from_url(url)
      u = url.downcase
      return "condo" if u.include?("can-ho")
      return "commercial" if u.match?(/van-phong|mat-bang|kho-xuong|nha-xuong/)
      return "house" if u.include?("nha")
      return "land" if u.include?("dat")

      "other"
    end

    # ".address" = "… , Ward , District , City"; trailing slots are the most reliable.
    def split_address(address)
      parts = address.split(",").map(&:strip).reject(&:empty?)
      city = parts[-1]
      district = parts[-2]
      ward = parts[-3]
      street = parts[0..-4]&.join(", ").presence
      [ ward, district, city, street ]
    end

    def area_from(doc)
      text = doc.css(".info-attr").map { |n| n.text.gsub(/\s+/, " ").strip }.join(" | ")
      num = text[/Diện tích đất\s+([\d.,]+)/, 1] ||
            text[/Diện tích sử dụng\s+([\d.,]+)/, 1] ||
            text[/Diện tích\s+([\d.,]+)/, 1]
      VnPrice.to_number(num) if num
    end

    def coordinates(html)
      m = html.match(/[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/)
      m ? [ m[1].to_f, m[2].to_f ] : [ nil, nil ]
    end

    # mogi lazy-loads gallery images, so the real URL is in src OR data-src.
    def image_urls(doc)
      doc.css("img")
        .flat_map { |img| [ img["src"], img["data-src"] ] }
        .compact
        .select { |src| src.include?("cloud.mogi.vn/images") }
        .reject { |src| src.include?("dmca") }
        .uniq
    end
  end
end
