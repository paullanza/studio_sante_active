FactoryBot.define do
  factory :fliip_service do
    fliip_user
    service_definition
    sequence(:remote_purchase_id) { |n| 90_000 + n }
    service_name    { "Entraînement privé" }
    purchase_status { "A" }
    purchase_date   { 10.days.ago }
    start_date      { 10.days.ago.to_date }
    expire_date     { 60.days.from_now.to_date }

    trait :without_definition do
      service_definition { nil }
      sequence(:service_id) { |n| 9_000 + n }
    end

    trait :cancelled do
      purchase_status { "C" }
    end
  end
end
