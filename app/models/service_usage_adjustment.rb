# An adjustment (« ajustement », GLOSSARY.md): one change to one service's
# counts, of one kind, for a trainer, with a required note (docs/adr/0002).
# « Séances utilisées » and « Absences utilisées » add to what is used;
# « Séances ajoutées » and « Absences ajoutées » add to what is allowed.
# Amounts are in half séances and may be negative.
class ServiceUsageAdjustment < ApplicationRecord
  KIND_LABELS = {
    "paid_used" => "Séances utilisées",
    "free_used" => "Absences utilisées",
    "paid_bonus" => "Séances ajoutées",
    "free_bonus" => "Absences ajoutées"
  }.freeze

  enum :kind, { paid_used: 0, free_used: 1, paid_bonus: 2, free_bonus: 3 }, validate: { message: "doit être choisi" }

  # The service whose counts change.
  belongs_to :fliip_service, inverse_of: :service_usage_adjustments
  # The trainer it counts for (Mes services lists the service for them).
  belongs_to :user, inverse_of: :service_usage_adjustments
  # The admin who entered it.
  belongs_to :created_by, class_name: "User"

  has_one :fliip_user, through: :fliip_service

  validates :note, presence: { message: "est requise" }, length: { maximum: 1000 }
  validates :amount, presence: { message: "est requis" }
  validates :amount, numericality: { other_than: 0, message: "doit être différent de 0" }, allow_nil: true
  validate :amount_in_half_seances

  def kind_label
    KIND_LABELS[kind]
  end

  # « +2 », « -0,5 ».
  def amount_label
    return "" if amount.nil?

    number = amount % 1 == 0 ? amount.abs.to_i.to_s : amount.abs.to_s.tr(".", ",")
    "#{amount.negative? ? '-' : '+'}#{number}"
  end

  private

  def amount_in_half_seances
    return if amount.nil? || (amount * 2) % 1 == 0

    errors.add(:amount, "doit être un multiple de 0,5")
  end
end
