FactoryBot.define do
  factory :session do
    user
    fliip_service
    fliip_user  { fliip_service.fliip_user }
    occurred_at { Time.current.change(min: 0) }
    present     { true }
    duration    { 1.0 }
  end
end
