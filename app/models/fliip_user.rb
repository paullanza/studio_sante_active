class FliipUser < ApplicationRecord
  validates :remote_id, presence: true, uniqueness: true
  has_many :fliip_contracts, dependent: :destroy
  has_many :fliip_services, dependent: :destroy
  has_many :sessions
end
