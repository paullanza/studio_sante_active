class CreateServiceUsageAdjustments < ActiveRecord::Migration[7.1]
  def change
    create_table :service_usage_adjustments do |t|
      t.references :fliip_service, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.float :paid_used_delta
      t.float :free_used_delta
      t.float :paid_bonus_delta
      t.string :idempotency_key

      t.timestamps
    end

    add_index :service_usage_adjustments, :idempotency_key, unique: true
  end
end
