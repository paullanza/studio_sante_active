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

  # `paid_sessions` (séances) and `free_sessions` (absences):
  #   - Must be integers >= 0
  #   - Are nil while the allocation is « à définir » (new kinds of service)
  #   - Saving an allocation (an update) requires both
  validates :paid_sessions, :free_sessions,
            numericality: { greater_than_or_equal_to: 0, only_integer: true },
            allow_nil: true
  validates :paid_sessions, :free_sessions, presence: true, on: :update

  # -----------------------------------------
  # Scopes
  # -----------------------------------------
  # Allocations an admin hasn't set yet (« à définir »).
  scope :to_define, -> { where(paid_sessions: nil).or(where(free_sessions: nil)) }

  # Name contains the query (ILIKE: any case, exact accents), or the DefID
  # is the query when it is a number.
  scope :matching, ->(query) {
    query = query.to_s.strip
    next all if query.blank?

    by_name = where("service_name ILIKE ?", "%#{sanitize_sql_like(query)}%")
    query.match?(/\A\d+\z/) ? by_name.or(where(service_id: query.to_i)) : by_name
  }

  # -----------------------------------------
  # Class Methods
  # -----------------------------------------
  # Creates an « à définir » definition (nil/nil), named after the service, for
  # each service type among these services that has none. Its services can't
  # be booked until an admin sets the allocation.
  def self.ensure_for!(fliip_services)
    by_type = fliip_services.reject { |s| s.service_id.blank? }.index_by(&:service_id)
    missing = by_type.keys - where(service_id: by_type.keys).pluck(:service_id)
    missing.each do |service_id|
      create!(service_id: service_id, service_name: by_type[service_id].service_name, paid_sessions: nil, free_sessions: nil)
    end
    missing.size
  end

  # -----------------------------------------
  # Instance Methods
  # -----------------------------------------
  # The allocation hasn't been set yet.
  def to_define?
    paid_sessions.nil? || free_sessions.nil?
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
