FactoryBot.define do
  factory :service_definition do
    sequence(:service_id) { |n| 500 + n }
    service_name  { "Entraînement privé" }
    paid_sessions { 10 }
    free_sessions { 2 }
  end
end
