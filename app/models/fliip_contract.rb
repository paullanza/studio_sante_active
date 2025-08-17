class FliipContract < ApplicationRecord
  # -----------------------------------------
  # Associations
  # -----------------------------------------
  # Each contract belongs to a specific FliipUser (client) in our system.
  belongs_to :fliip_user, inverse_of: :fliip_contracts

  # -----------------------------------------
  # Status Mapping
  # -----------------------------------------
  # The `status` field is a code returned from the Fliip API.
  # This map translates those codes into human-readable strings:
  #   "A" → Active
  #   "I" → Inactive
  #   "C" → Cancelled
  #   "S" → Stopped
  STATUS_MAP = {
    "A" => "Active",
    "I" => "Inactive",
    "C" => "Cancelled",
    "S" => "Stopped"
  }.freeze

  # -----------------------------------------
  # Scopes
  # -----------------------------------------
  # Filter contracts based on their status code.
  scope :active,    -> { where(status: "A") }
  scope :inactive,  -> { where(status: "I") }
  scope :cancelled, -> { where(status: "C") }
  scope :stopped,   -> { where(status: "S") }

  # Contracts with no status set (e.g., incomplete or missing data).
  scope :unknown,   -> { where(status: nil) }

  # -----------------------------------------
  # Instance Methods
  # -----------------------------------------
  # Returns the human-readable name for the contract's status.
  # If the status is not recognized, defaults to "Unknown".
  def status_name
    STATUS_MAP.fetch(status, "Unknown")
  end
end
