class CreateFliipServices < ActiveRecord::Migration[7.1]
  def change
    create_table :fliip_services do |t|
      t.bigint :remote_purchase_id
      t.references :fliip_user, null: false, foreign_key: true
      t.string :purchase_status
      t.date :start_date
      t.date :expire_date
      t.datetime :purchase_date
      t.date :stop_date
      t.date :cancel_date
      t.string :rebate
      t.boolean :stop_payments
      t.string :discount_name
      t.integer :service_id
      t.string :service_name
      t.string :service_type
      t.string :service_category_name
      t.string :coach
      t.string :payment_terms
      t.string :duration
      t.string :online_enabled
      t.string :service_description
      t.integer :billed_at_purchase
      t.string :ledger_account

      t.timestamps
    end
    add_index :fliip_services, :remote_purchase_id
  end
end
