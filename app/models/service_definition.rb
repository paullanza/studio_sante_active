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
  # Creates ServiceDefinition records for any FliipService service_id
  # that does not already have a definition.
  #
  # Steps:
  #   1. Fetch all distinct service_ids from FliipService.
  #   2. Fetch all existing service_ids from ServiceDefinition.
  #   3. Find missing IDs by subtracting existing from all found.
  #   4. For each missing ID:
  #        - Find one example FliipService with that ID
  #        - Create a definition with:
  #            service_id   → from FliipService
  #            service_name → from FliipService
  #            paid_sessions / free_sessions set to 0 by default
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
