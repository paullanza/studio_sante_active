class CreateSignupCodes < ActiveRecord::Migration[7.0]
  def change
    create_table :signup_codes do |t|
      t.string :code, null: false
      t.integer :status, null: false, default: 0
      t.datetime :expiry_date, null: false
      t.references :used_by, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    add_index :signup_codes, :code, unique: true
  end
end
