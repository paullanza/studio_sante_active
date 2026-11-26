FactoryBot.define do
  factory :service_usage_adjustment do
    fliip_service
    user
    created_by factory: %i[user admin]
    kind { :paid_bonus }
    amount { 1.0 }
    note { "Ajustement" }

    trait(:paid_used) { kind { :paid_used } }
    trait(:free_used) { kind { :free_used } }
    trait(:paid_bonus) { kind { :paid_bonus } }
    trait(:free_bonus) { kind { :free_bonus } }
  end
end
