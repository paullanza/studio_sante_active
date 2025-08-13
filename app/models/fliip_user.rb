class FliipUser < ApplicationRecord
  include PgSearch::Model

  validates :remote_id, presence: true, uniqueness: true
  has_many :fliip_contracts, dependent: :destroy
  has_many :fliip_services, dependent: :destroy
  has_many :sessions

  pg_search_scope :search_clients,
    against: [:user_firstname, :user_lastname, :user_email, :remote_id],
    using: {
      tsearch: { prefix: true, dictionary: 'simple' }
    }

    def full_name
      "#{user_firstname} #{user_lastname}"
    end
end
