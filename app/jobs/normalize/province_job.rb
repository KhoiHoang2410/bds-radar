module Normalize
  # Builds/refreshes RealEstate rows from a province's sources — ALL suppliers for
  # the province (per-province sharding, NOT per-supplier), so v2 cross-source merge
  # becomes a change to this loop body, not a re-shard. v1 is strictly 1:1 (keyed by
  # real_estate_source_id). Idempotent.
  class ProvinceJob < ApplicationJob
    queue_as :default

    def perform(province_id)
      province = Province.find(province_id)
      province.real_estate_sources.find_each { |source| upsert(source, province) }
    end

    private

    def upsert(source, province)
      real_estate = RealEstate.find_or_initialize_by(real_estate_source_id: source.id)
      real_estate.assign_attributes(
        latitude: source.latitude,
        longitude: source.longitude,
        province_id: source.province_id,                  # canonical (filter key)
        province: source.province,                        # raw display
        district_or_city: source.district_or_city,
        ward: source.ward,
        area: source.area,
        price: source.price,
        type: source.type,
        image_urls: source.image_urls,
        source_urls: Array(source.source_url).compact_blank,
        status: source.status,                            # inactive source ⇒ inactive RE
        bedrooms: source.bedrooms,                        # promoted listing details (#21)
        bathrooms: source.bathrooms,
        posted_at: source.posted_at,
        title: source.title,
        ward_city_id: WardCityMatcher.call(ward: source.ward, province: province.name)
      )
      real_estate.save!
    end
  end
end
