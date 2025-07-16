class CreateFliipUserNotes < ActiveRecord::Migration[7.1]
  def change
    create_table :fliip_user_notes do |t|
      t.text :note_text
      t.date :created_date
      t.string :creator_of_note_full_name
      t.references :fliip_user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
