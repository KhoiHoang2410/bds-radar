FactoryBot.define do
  factory :ward do
    sequence(:ward) { |n| "Phường Số #{n}" }
    association :province
    ward_alternatives { [] }
  end
end
