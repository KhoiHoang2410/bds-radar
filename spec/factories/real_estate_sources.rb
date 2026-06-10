FactoryBot.define do
  factory :real_estate_source do
    association :crawl_province, factory: :province
    supplier { "nhatot" }
    sequence(:external_id) { |n| "L#{n}" }
    status { "active" }
    raw_data { {} }
    type { "house" }
    price { 5_000_000_000 }
    area { 50.0 }
    address { "Đường Đặng Lộ, Phường 7, Quận Tân Bình, Tp Hồ Chí Minh" }
    province { "Tp Hồ Chí Minh" }
    district_or_city { "Quận Tân Bình" }
    ward { "Phường 7" }
    street { "Đường Đặng Lộ" }
    image_urls { [ "https://cdn.chotot.com/a.jpg" ] }
    source_url { "https://www.nhatot.com/1.htm" }
    latitude { 10.786219 }
    longitude { 106.65734 }
    last_seen_at { Time.current }

    trait :inactive do
      status { "inactive" }
    end
  end
end
