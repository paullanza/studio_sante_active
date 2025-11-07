class FliipUser < ApplicationRecord
  include PgSearch::Model

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

  def best_active_contract_for_index
    active = fliip_contracts.select { |c| c.status == "A" }
    return nil if active.empty?
    active.max_by { |c| [(c.end_date || Date.new(0)), (c.start_date || Date.new(0))] }
  end
end
