# Step 3 of 3 for one change per adjustment (docs/adr/0002): every row now
# holds one change, so the new columns become required and the old three
# columns go. Rolling back brings the old columns back empty; roll back step 2
# right after to fill them again.
class FinalizeOneChangeAdjustments < ActiveRecord::Migration[8.1]
  def change
    change_column_null :service_usage_adjustments, :kind, false
    change_column_null :service_usage_adjustments, :amount, false
    change_column_null :service_usage_adjustments, :note, false
    change_column_null :service_usage_adjustments, :created_by_id, false

    remove_column :service_usage_adjustments, :paid_used_delta, :float
    remove_column :service_usage_adjustments, :free_used_delta, :float
    remove_column :service_usage_adjustments, :bonus_sessions, :float
  end
end
