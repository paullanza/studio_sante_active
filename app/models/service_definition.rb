class ServiceDefinition < ApplicationRecord
  def self.create_missing_definitions!
    service_ids = FliipService.distinct.pluck(:service_id)
    existing_ids = ServiceDefinition.pluck(:service_id)

    (service_ids - existing_ids).each do |missing_id|
      create!(service_id: missing_id, paid_sessions: 0, free_sessions: 0)
    end
  end
end
