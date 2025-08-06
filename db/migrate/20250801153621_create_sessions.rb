class CreateSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :fliip_user, null: false, foreign_key: true
      t.references :fliip_service, null: false, foreign_key: true
      t.date :date
      t.time :time
      t.boolean :present
      t.text :note
      t.boolean :confirmed
      t.string :session_type, null: false, default: "paid"
      t.float :duration, null: false, default: 1

      t.timestamps
    end
  end
end
