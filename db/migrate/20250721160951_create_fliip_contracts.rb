class CreateFliipContracts < ActiveRecord::Migration[7.1]
  def change
    create_table :fliip_contracts do |t|
      t.bigint :remote_contract_id
      t.references :fliip_user, null: false, foreign_key: true
      t.string :status
      t.date :start_date
      t.date :end_date
      t.date :stop_date
      t.date :resume_date
      t.date :cancel_date
      t.string :rebate
      t.string :discount_name
      t.string :main_user_contract
      t.string :membership_name
      t.string :plan_base_type
      t.string :plan_type
      t.text :plan_description
      t.string :plan_classes
      t.string :payment_terms
      t.string :duration
      t.string :billed_at_purchase
      t.string :ledger_account
      t.string :pack_class_num
      t.string :pack_class_used

      t.timestamps
    end
    add_index :fliip_contracts, :remote_contract_id
  end
end
