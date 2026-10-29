FactoryBot.define do
  factory :service_usage_adjustment do
    fliip_service
    user
    bonus_sessions  { 0 }
    free_used_delta { 0 }
    # At least one delta must be non-zero, so default to one paid session used
    # unless the spec sets another delta.
    paid_used_delta { bonus_sessions.to_f.zero? && free_used_delta.to_f.zero? ? 1 : 0 }
  end
end
