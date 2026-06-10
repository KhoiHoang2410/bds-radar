module Suppliers
  # Value object a Supplier#normalize returns: the 6 mandatory fields + coords +
  # raw admin path + raw_data. Transport/parsing-agnostic; the fetch job maps it
  # onto a RealEstateSource row.
  Listing = Struct.new(
    :supplier, :external_id, :source_url, :type, :price, :area,
    :address, :province, :district_or_city, :ward, :street,
    :image_urls, :latitude, :longitude, :raw_data,
    keyword_init: true
  ) do
    # Parsed columns for upsert (province_id / status / last_seen_at set by the job).
    def to_attributes
      {
        source_url: source_url,
        type: type,
        price: price,
        area: area,
        address: address,
        province: province,
        district_or_city: district_or_city,
        ward: ward,
        street: street,
        image_urls: Array(image_urls),
        latitude: latitude,
        longitude: longitude,
        raw_data: raw_data
      }
    end
  end
end
