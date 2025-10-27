class FliipUser < ApplicationRecord
  # -----------------------------------------
  # Includes
  # -----------------------------------------
  # PgSearch::Model adds full-text search capabilities using PostgreSQL.
  include PgSearch::Model

  # -----------------------------------------
  # Validations
  # -----------------------------------------
  # - remote_id: Required and must be unique.
  #   This ensures we correctly map each record to its counterpart in the remote Fliip API.
  validates :remote_id, presence: true, uniqueness: true

  # -----------------------------------------
  # Associations
  # -----------------------------------------
  # A FliipUser can have multiple related contracts from the Fliip API.
  # If the FliipUser is deleted, all associated contracts are also deleted.
  has_many :fliip_contracts, dependent: :destroy, inverse_of: :fliip_user

  # A FliipUser can have multiple related services from the Fliip API.
  # If the FliipUser is deleted, all associated services are also deleted.
  has_many :fliip_services,  dependent: :destroy, inverse_of: :fliip_user

  # A FliipUser can have many session records in our app.
  # Restrict deletion if there are existing sessions (adds validation error instead of deleting).
  has_many :sessions,        dependent: :restrict_with_error, inverse_of: :fliip_user

  has_many :consultations, dependent: :nullify, inverse_of: :fliip_user

  # Scopes (add this)
  scope :with_service_after, ->(date) {
    return none if date.blank?
    joins(:fliip_services)
      .where("COALESCE(fliip_services.start_date, fliip_services.purchase_date) > ?", date)
      .distinct
  }

  # -----------------------------------------
  # Search Scope
  # -----------------------------------------
  # Enables full-text search for clients by:
  #   - First name
  #   - Last name
  #   - Email
  #   - Remote ID
  # Uses PostgreSQL's tsearch with:
  #   - prefix: true   → matches partial words (e.g., "Jon" matches "Jonathan")
  #   - dictionary: 'simple' → basic word parsing without stemming
  pg_search_scope :search_clients,
    against: [:user_firstname, :user_lastname, :user_email, :remote_id],
    using: {
      tsearch: { prefix: true, dictionary: 'simple' }
    },
    ignoring: :accents

  # -----------------------------------------
  # Instance Methods
  # -----------------------------------------
  # Returns the full name of the client by combining first and last names.
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

  # If no suitable service, show the best active contract
  def best_active_contract_for_index
    active = fliip_contracts.select { |c| c.status == "A" }
    return nil if active.empty?
    active.max_by { |c| [(c.end_date || Date.new(0)), (c.start_date || Date.new(0))] }
  end
end
