class CreateSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :fliip_user, null: false, foreign_key: true
      t.references :fliip_service, null: false, foreign_key: true
      t.references :created_by,    null: false, foreign_key: { to_table: :users }
      t.datetime :confirmed_at
      t.date :date
      t.time :time
      t.boolean :present
      t.text :note
      t.boolean :confirmed
      t.integer :session_type, null: false, default: "paid"
      t.float :duration, null: false, default: 1

      t.timestamps
    end
  end
end
