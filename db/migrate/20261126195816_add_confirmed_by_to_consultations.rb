# The admin who confirmed a consultation for payroll, as on séances. Nullable
# with no backfill: older confirmations didn't record it. The consultations
# table is small, so a plain index and foreign key are fine.
class AddConfirmedByToConsultations < ActiveRecord::Migration[8.1]
  def change
    add_reference :consultations, :confirmed_by, foreign_key: { to_table: :users }, null: true
  end
end
