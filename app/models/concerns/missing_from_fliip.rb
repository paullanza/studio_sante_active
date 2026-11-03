# Records mirrored from Fliip that Fliip stopped returning are flagged with
# missing_from_fliip_at, never deleted. The sync sets and clears the flag.
module MissingFromFliip
  extend ActiveSupport::Concern

  included do
    scope :missing_from_fliip, -> { where.not(missing_from_fliip_at: nil) }
    scope :present_in_fliip,   -> { where(missing_from_fliip_at: nil) }
  end

  def missing_from_fliip?
    missing_from_fliip_at.present?
  end
end
