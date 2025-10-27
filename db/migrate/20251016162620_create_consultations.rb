class CreateConsultations < ActiveRecord::Migration[7.1]
  def change
    create_table :consultations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :fliip_user, foreign_key: true
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :phone_number
      t.datetime :confirmed_at
      t.text :note
      t.boolean :confirmed
      t.boolean :present
      t.datetime :occurred_at

      t.timestamps
    end
  end
end
