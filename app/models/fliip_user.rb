class FliipUser < ApplicationRecord
  has_many :fliip_user_notes, dependent: :destroy
  has_many :fliip_user_appointment_notes, dependent: :destroy
end
