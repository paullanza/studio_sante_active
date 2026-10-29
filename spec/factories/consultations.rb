FactoryBot.define do
  factory :consultation do
    user
    first_name   { Faker::Name.first_name }
    last_name    { Faker::Name.last_name }
    phone_number { Faker::PhoneNumber.phone_number }
    occurred_at  { 1.day.ago }
  end
end
