FactoryBot.define do
  factory :real_estate do
    association :crawl_province, factory: :province
    real_estate_source
    ward_city { nil }
    status { "active" }
    type { "house" }
    price { 5_000_000_000 }
    area { 50.0 }
    province { "Tp Hồ Chí Minh" }
    district_or_city { "Quận Tân Bình" }
    ward { "Phường 7" }
    latitude { 10.786219 }
    longitude { 106.65734 }
    image_urls { [] }
    source_urls { [ "https://www.nhatot.com/1.htm" ] }

    trait :inactive do
      status { "inactive" }
    end
  end
end
