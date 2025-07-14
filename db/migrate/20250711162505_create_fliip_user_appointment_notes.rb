class CreateFliipUserAppointmentNotes < ActiveRecord::Migration[7.1]
  def change
    create_table :fliip_user_appointment_notes do |t|
      t.text :note_text
      t.datetime :created_date
      t.string :creator_of_note_full_name
      t.string :service_name
      t.datetime :appointment_start
      t.references :fliip_user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
