FactoryBot.define do
  factory :fliip_contract do
    fliip_user
    sequence(:remote_contract_id) { |n| 70_000 + n }
    status          { "A" }
    membership_name { "Abonnement mensuel" }
    start_date      { 30.days.ago.to_date }
    end_date        { 335.days.from_now.to_date }

    trait :inactive do
      status { "I" }
    end

    trait :cancelled do
      status { "C" }
    end

    trait :stopped do
      status { "S" }
    end
  end
end
