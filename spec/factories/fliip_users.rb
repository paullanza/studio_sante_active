FactoryBot.define do
  factory :fliip_user do
    sequence(:remote_id) { |n| 10_000 + n }
    user_firstname { Faker::Name.first_name }
    user_lastname  { Faker::Name.last_name }
    user_email     { Faker::Internet.email }
    user_role      { "user" }
  end
end
