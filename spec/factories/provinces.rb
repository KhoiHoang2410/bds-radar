FactoryBot.define do
  factory :province do
    sequence(:name) { |n| "Province #{n}" }
    alternatives { [] }
    schedule_fetch { false }
    fetch_page_depth { 5 }

    trait :scheduled do
      schedule_fetch { true }
    end
  end
end
