FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }
    sequence(:email) { |n| "staff#{n}@example.com" }
    password   { "password123" }
    phone      { Faker::PhoneNumber.phone_number }
    address    { Faker::Address.full_address }
    birthday   { Faker::Date.birthday(min_age: 18, max_age: 65) }
    signup_code_token { create(:signup_code).code }
    role { :employee }

    trait :manager do
      role { :manager }
    end

    trait :admin do
      role { :admin }
    end

    trait :super_admin do
      role { :super_admin }
    end

    trait :inactive do
      active { false }
    end
  end
end
