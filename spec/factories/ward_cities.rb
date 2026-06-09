FactoryBot.define do
  factory :ward_city do
    sequence(:ward) { |n| "Phường Số #{n}" }
    province { "Hồ Chí Minh" }
    ward_alternatives { [] }
    province_alternatives { [] }
  end
end
