# Step 1 of 3 for one change per adjustment (docs/adr/0002): the new columns,
# nullable until the old rows are split (step 2) and the constraints land
# (step 3). The table holds a few hundred rows.
class AddKindAmountNoteToServiceUsageAdjustments < ActiveRecord::Migration[8.1]
  def change
    add_column :service_usage_adjustments, :kind, :integer
    add_column :service_usage_adjustments, :amount, :float
    add_column :service_usage_adjustments, :note, :text
    add_reference :service_usage_adjustments, :created_by, foreign_key: { to_table: :users }
  end
end
