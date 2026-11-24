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

  # Families of the Allocations page, in display order, each with the name
  # pattern that puts a kind of service in it. The first match wins, so DUO
  # comes before EP and Ent. privé. A name nothing matches goes to « Autres »:
  # add a pattern here when a new family appears in Fliip.
  FAMILIES = [
    [ "DUO",        /\A(EPDUO|Ent\. privé DUO|Duo)\b/i ],
    [ "Personnel",  /\ASTAFF\b/ ],
    [ "EP",         /\AEP\b/ ],
    [ "Ent. privé", /\AEnt\. privé\b/i ],
    [ "Semi-privé", /semi-privé/i ],
    [ "Visio",      /visio/i ],
    [ "Pilates",    /\APilates\b/i ],
    [ "À la carte", /\AÀ la carte\b/i ]
  ].freeze
  OTHER_FAMILY = "Autres".freeze
  FAMILY_ORDER = [ "Ent. privé", "EP", "DUO", "Semi-privé", "Pilates", "Visio", "À la carte", "Personnel", OTHER_FAMILY ].freeze

  # -----------------------------------------
  # Instance Methods
  # -----------------------------------------
  # The allocation hasn't been set yet.
  def to_define?
    paid_sessions.nil? || free_sessions.nil?
  end

  # Same, by the saved values (ignores values assigned but not saved).
  def to_define_in_database?
    paid_sessions_in_database.nil? || free_sessions_in_database.nil?
  end

  # The family the Allocations page groups this kind of service under.
  def family
    name = service_name.to_s.strip
    FAMILIES.find { |_, pattern| name.match?(pattern) }&.first || OTHER_FAMILY
  end

  # Séances read from the name, as a hint when setting the allocation; nil
  # when the name doesn't say. Never saved on its own.
  #   « (48 séances) » → 48, « (24 séances de 30 minutes) » → 12 (half each),
  #   « 10 visites » → 10, « 6 mois - 2x/sem » → 48 (4 weeks a month),
  #   « 12 mois - 2x/mois » → 24.
  def suggested_paid_sessions
    name = service_name.to_s

    if (match = name.match(/\((\d+) séances( de 30 min)?/i))
      count = match[1].to_i
      return match[2] ? count / 2 : count
    end
    return Regexp.last_match(1).to_i if name =~ /(\d+) visites/i

    months = name[/(\d+) mois/i, 1]&.to_i
    return unless months

    if (per_week = name[%r{(\d+)x/sem}i, 1])
      per_week.to_i * 4 * months
    elsif (per_month = name[%r{(\d+)x/mois}i, 1])
      per_month.to_i * months
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
