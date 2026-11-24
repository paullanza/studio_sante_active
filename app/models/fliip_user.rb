class FliipUser < ApplicationRecord
  include PgSearch::Model
  include MissingFromFliip

  validates :remote_id, presence: true, uniqueness: true

  has_many :fliip_contracts, dependent: :destroy, inverse_of: :fliip_user
  has_many :fliip_services,  dependent: :destroy, inverse_of: :fliip_user
  has_many :sessions,        dependent: :restrict_with_error, inverse_of: :fliip_user
  has_many :consultations,  dependent: :destroy, inverse_of: :fliip_user

  # Users that have at least one service (any date)
  scope :with_any_services, -> {
    joins(:fliip_services).distinct
  }

  # Users that have a service whose start/purchase is on/after a date
  scope :with_service_after, ->(date) {
    return none if date.blank?
    joins(:fliip_services)
      .where("COALESCE(fliip_services.start_date, fliip_services.purchase_date) >= ?", date)
      .distinct
  }

  pg_search_scope :search_clients,
    against: [:user_firstname, :user_lastname, :user_email, :remote_id],
    using: {
      tsearch: { prefix: true, dictionary: 'simple' }
    },
    ignoring: :accents

  PHONE_SEARCH_MIN_DIGITS = 4

  # The one entry point for client search (the Clients page).
  # A query of digits only, in any phone format (« 514-555-0142 », « 555 0142 »),
  # matches either phone with its formatting stripped, or the FliipUserID
  # exactly. Anything else goes through the accent-insensitive search_clients.
  # The table holds a few thousand rows, so the regexp_replace scan needs no index.
  def self.search(query)
    query = query.to_s.strip
    return none if query.length < 2

    digits = query.gsub(/\D/, "")
    if digits.length >= PHONE_SEARCH_MIN_DIGITS && query !~ /\p{L}/
      search_by_phone(digits)
    else
      search_clients(query)
    end
  end

  def self.search_by_phone(digits)
    where(
      "regexp_replace(coalesce(user_phone1, ''), '\\D', '', 'g') LIKE :d " \
      "OR regexp_replace(coalesce(user_phone2, ''), '\\D', '', 'g') LIKE :d " \
      "OR remote_id::text = :id",
      d: "%#{sanitize_sql_like(digits)}%", id: digits
    ).order(:user_firstname, :user_lastname)
  end
  private_class_method :search_by_phone

  def full_name
    "#{user_firstname} #{user_lastname}"
  end

  def most_recent_index_service
    return nil unless association(:fliip_services).loaded? || fliip_services.loaded? || fliip_services.exists?

    allowed = fliip_services.select { |s| %w[A S P].include?(s.purchase_status) }
    %w[A S P].each do |code|
      bucket = allowed.select { |s| s.purchase_status == code }
      next if bucket.empty?
      return bucket.max_by { |s| [(s.expire_date || Date.new(0)), (s.start_date || Date.new(0))] }
    end
    nil
  end

  # What the Clients list shows for a client: an active service, else an
  # active abonnement, else a stopped or planned service.
  def main_index_item
    service = most_recent_index_service
    return service if service&.purchase_status == "A"

    best_active_contract_for_index || service
  end

  def best_active_contract_for_index
    active = fliip_contracts.select { |c| c.status == "A" }
    return nil if active.empty?
    active.max_by { |c| [(c.end_date || Date.new(0)), (c.start_date || Date.new(0))] }
  end

  # The Client page's top card. Services count when active in Fliip and not
  # removed from it; a service without an allocation adds no séances.
  def last_session_at
    sessions.maximum(:occurred_at)
  end

  def active_services_count
    countable_services.size
  end

  def remaining_sessions_total
    countable_services.sum { |s| s.remaining_paid_sessions.to_f }
  end

  def staff?
    user_role.present? && user_role != "user"
  end

  private

  def countable_services
    fliip_services.select { |s| s.purchase_status == "A" && !s.removed_from_fliip? }
  end
end
