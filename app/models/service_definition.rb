class ServiceDefinition < ApplicationRecord
  # -----------------------------------------
  # Associations
  # -----------------------------------------
  # A ServiceDefinition represents the internal definition or template
  # for a service type in our system.
  # It links to FliipService records using a non-standard key mapping:
  #   - `primary_key` here is `service_id` on ServiceDefinition
  #   - `foreign_key` on FliipService is also `service_id`
  has_many :fliip_services,
           primary_key: :service_id,
           foreign_key: :service_id

  # -----------------------------------------
  # Validations
  # -----------------------------------------
  # `service_id` must be present and unique (maps to external service identifier).
  validates :service_id, presence: true, uniqueness: true

  # `paid_sessions` and `free_sessions`:
  #   - Must be integers >= 0
  #   - Can be nil if not yet defined
  validates :paid_sessions, :free_sessions,
            numericality: { greater_than_or_equal_to: 0, only_integer: true },
            allow_nil: true

  # -----------------------------------------
  # Class Methods
  # -----------------------------------------
  # Creates a 0/0 definition, named after the service, for each service type
  # among these services that has none. Admins set the allowance later.
  def self.ensure_for!(fliip_services)
    by_type = fliip_services.reject { |s| s.service_id.blank? }.index_by(&:service_id)
    missing = by_type.keys - where(service_id: by_type.keys).pluck(:service_id)
    missing.each do |service_id|
      create!(service_id: service_id, service_name: by_type[service_id].service_name, paid_sessions: 0, free_sessions: 0)
    end
    missing.size
  end

  # -----------------------------------------
  # (Commented Out) Class Method: Backfill Service Names
  # -----------------------------------------
  # This method would update any ServiceDefinitions missing a service_name
  # by looking up the corresponding FliipService record and copying its name.
  #
  # def self.backfill_service_names!
  #   where(service_name: [nil, ""]).find_each do |definition|
  #     fliip_service = FliipService.find_by(service_id: definition.service_id)
  #
  #     if fliip_service&.service_name.present?
  #       definition.update!(service_name: fliip_service.service_name)
  #     end
  #   end
  # end
end
