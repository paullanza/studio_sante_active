class ServiceDefinition < ApplicationRecord
  def self.create_missing_definitions!
    service_ids = FliipService.distinct.pluck(:service_id)
    existing_ids = ServiceDefinition.pluck(:service_id)

    (service_ids - existing_ids).each do |missing_id|
      fliip_service = FliipService.find_by(service_id: missing_id)

      create!(
        service_id: fliip_service.service_id,
        service_name: fliip_service.service_name,
        paid_sessions: 0,
        free_sessions: 0
      )
    end
  end

  # def self.backfill_service_names!
  #   where(service_name: [nil, ""]).find_each do |definition|
  #     fliip_service = FliipService.find_by(service_id: definition.service_id)

  #     if fliip_service&.service_name.present?
  #       definition.update!(service_name: fliip_service.service_name)
  #     end
  #   end
  # end
end
